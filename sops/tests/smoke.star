# sops/tests/smoke.star — stable across upstream sops releases.
#
# Asserts the contract (a real encrypt→decrypt round trip, a documented exit
# STATUS constant, and sops's own machine-readable file status), never
# help/version prose.
#
# HERMETIC BY CONSTRUCTION, AND OFFLINE BY CONSTRUCTION. sops's other backends
# (AWS KMS, GCP KMS, Azure Key Vault, HashiCorp Vault, PGP) all need a network
# service or an external `gpg` binary. The **age** backend needs neither: X25519
# + ChaCha20-Poly1305 are compiled into the binary, so a full round trip runs
# with no network, no key server and no second executable. The keypair below is
# generated for this test and used nowhere else — it protects nothing.
#
# `SOPS_DISABLE_VERSION_CHECK` is not cosmetic: by default `sops --version`
# makes an HTTP call to GitHub to report whether the build is the latest, and
# prints `(latest)`/`(latest available: …)` accordingly. That would put a
# network dependency — and a non-deterministic banner — inside the smoke. With
# the variable set, stdout is exactly `sops <version>\n` (measured, `od -c`).
#
# Everything below was measured against the real 3.13.1 and 3.13.3 linux/amd64
# binaries, and the whole sequence was replayed inside
# `docker run --network none alpine:3.20` with HOME unset — which is also why
# ../../mirror-base.yml provisions nothing via `containers[].setup`.

SOPS = "sops.exe" if ocx.target_platform.os == ocx.os.Windows else "sops"

# Throwaway age keypair. Hardcoding the identity is what makes the test
# hermetic: no `age-keygen` is shipped by this package and none is needed.
AGE_RECIPIENT = "age1pnexrx2thvq8h8dm8aa996cx87kq2th6pcvwc2323arrxp7hr3rsc6j803"
AGE_IDENTITY = "AGE-SECRET-KEY-1ZZWVD20AG0YPXQUAYQT324V33TGY5YEAZ2VSR40XR58WDMK099HQRNSS7A"

# The plaintext. TOKEN appears in no argument sops is handed on the decrypt
# side, so it can only come back out of the ciphertext.
TOKEN = "OCXSMOKE_PLAINTEXT_7F21"
PLAINTEXT = "token: " + TOKEN + "\n"

# HOME is pinned to scratch so the "no key" negative control below is genuinely
# keyless — sops falls back to `$HOME`-rooted age key files when SOPS_AGE_KEY is
# unset, and an unset/unwritable HOME is its own failure mode in containers.
NO_KEY = {"HOME": ocx.scratch_root, "SOPS_DISABLE_VERSION_CHECK": "true"}
WITH_KEY = {
    "HOME": ocx.scratch_root,
    "SOPS_DISABLE_VERSION_CHECK": "true",
    "SOPS_AGE_KEY": AGE_IDENTITY,
}

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; any banner around them is not. An
# `expect.eq(stdout, "sops 3.13.3")` would red on the next release and an
# `expect.contains(stdout, "sops")` would break on a rebrand.
r_version = ocx.run(SOPS, "--version", env = NO_KEY)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── Hermetic fixtures ──────────────────────────────────────────────────────
#
# `cwd` defaults to the scratch root, so every path below stays relative and is
# correct on Windows too, with no separator juggling.
#
# The empty `.sops.yaml` exists to be named by `--config`. Without it sops walks
# PARENT directories looking for a creation-rules file, and the scratch root's
# ancestors are not ours to reason about; `--config` stops the search dead.
ocx.write_file(".sops.yaml", "")
ocx.write_file("secrets.yaml", PLAINTEXT)

# ─── Tier 3a: encrypt — and the passthrough negative control ────────────────
#
# A tool that merely copied its input would satisfy "exit 0" and "produced
# output". The assertions that make this a real check are the two below it: the
# plaintext token must be GONE, and sops's own ciphertext markers must be
# present. `ENC[AES256_GCM,` appears exactly twice — once for the single
# encrypted value (`token`) and once for the document MAC — so the count also
# pins that the MAC layer ran.
r_enc = ocx.run(SOPS, "--config", ".sops.yaml", "encrypt", "--age", AGE_RECIPIENT, "secrets.yaml", env = NO_KEY)
expect.ok(r_enc)
expect.eq(r_enc.stdout.count(TOKEN), 0)
expect.eq(r_enc.stdout.count("ENC[AES256_GCM,"), 2)
expect.contains(r_enc.stdout, "sops:")
expect.contains(r_enc.stdout, AGE_RECIPIENT)

ocx.write_file("enc.yaml", r_enc.stdout)

# ─── Tier 3b: decrypt — the round trip, byte for byte ───────────────────────
#
# Not "contains the token": the whole document must come back identical to what
# went in. `.strip()` absorbs a trailing newline difference only.
r_dec = ocx.run(SOPS, "--config", ".sops.yaml", "decrypt", "enc.yaml", env = WITH_KEY)
expect.ok(r_dec)
expect.eq(r_dec.stdout.strip(), PLAINTEXT.strip())

# ─── Tier 3c: THE NEGATIVE CONTROL — decrypt with the key absent ────────────
#
# Identical invocation, `SOPS_AGE_KEY` removed and HOME pointed at a scratch
# directory holding no age key file. If the value had never really been
# encrypted — or if the age backend were a no-op — this would succeed and print
# the token. 128 is sops's own documented status constant `CouldNotRetrieveKey`
# (cmd/sops/codes/codes.go), a named part of its interface rather than a
# happens-to-be number, and it is POSITIVE — so it is unaffected by the
# unix-255/windows-(-1) split that negative exit codes suffer.
r_nokey = ocx.run(SOPS, "--config", ".sops.yaml", "decrypt", "enc.yaml", env = NO_KEY)
expect.eq(r_nokey.exit_code, 128)
expect.eq(r_nokey.stdout.count(TOKEN), 0)

# ─── Tier 3d: `filestatus` — a machine-readable verdict, both directions ────
#
# sops's own JSON, byte-exact and colourless (measured with `od -c`). Asserting
# BOTH directions is what makes it a check: a `filestatus` that answered
# `{"encrypted":true}` unconditionally would pass the first line alone.
r_fs_enc = ocx.run(SOPS, "--config", ".sops.yaml", "filestatus", "enc.yaml", env = NO_KEY)
expect.ok(r_fs_enc)
expect.eq(r_fs_enc.stdout.strip(), '{"encrypted":true}')

r_fs_plain = ocx.run(SOPS, "--config", ".sops.yaml", "filestatus", "secrets.yaml", env = NO_KEY)
expect.ok(r_fs_plain)
expect.eq(r_fs_plain.stdout.strip(), '{"encrypted":false}')

# No Tier 4: metadata.json declares PATH only (proven by the Tier 1 liveness
# call resolving `sops` off the composed PATH).
