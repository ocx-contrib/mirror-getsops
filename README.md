# mirror-getsops

OCX mirror for [sops](https://github.com/getsops/sops), the encrypted-file
editor published by the CNCF **getsops** project. One repository, one spec
directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [sops](https://github.com/getsops/sops) | [`sops/mirror.yml`](sops/mirror.yml) | `ghcr.io/ocx-contrib/getsops/sops` | [`ocx.sh/getsops/sops`](https://index.ocx.sh/getsops/sops) | `MPL-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`getsops` is the project's own GitHub org and brand — the tool's website is
getsops.io — rather than a maintainer's personal handle, so the org names the
namespace: the package is `getsops/sops`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
sops/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `sops/mirror.yml` does not restate it at all, which removes the
trap structurally.

## Platforms

`sops` publishes six platform entries: both Linux arches, both macOS arches and
both Windows arches — `windows/arm64` genuinely exists upstream and is
declared. Upstream ships one Go binary per platform with no musl/gnu split, and
all four declared Linux artifacts were byte-measured at **both ends** of the
mirrored range, 3.13.1 and 3.13.3: no `PT_INTERP`, no `DT_NEEDED`, no UPX stub
(`strings -a | grep -c '^UPX'` → 0, 16 section headers present). `os.features`
states what an artifact requires *of the host*, so both Linux keys are **bare**
— `+libc.glibc` would hide the package from Alpine and `+libc.musl` would hide
it from every glibc host it in fact runs on. The `alpine:3.20` container leg on
both arches in `mirror-base.yml` is what turns that claim into evidence; the
measurement transcript is recorded above the `assets:` block in
`sops/mirror.yml`.

Upstream also publishes `.deb` and `.rpm` packages, per-binary
`.spdx.sbom.json` SBOMs, checksum and sigstore sidecars, and one whole-release
`.intoto.jsonl` SLSA provenance file. None is a platform artifact, and none is
mirrored.

### Raw binaries, and the two naming traps

Every asset is an **uncompressed binary** — no tarball, no zip, and no bare
`.gz` twin to false-green on.

1. **darwin triple-matches.** Alongside `sops-vX.Y.Z.darwin.amd64` and
   `sops-vX.Y.Z.darwin.arm64`, upstream ships a bare, arch-less
   `sops-vX.Y.Z.darwin` on every release. A `.*darwin.*` pattern matches all
   three, which is a hard ambiguous error; a near-miss pattern would silently
   take the wrong file. Both darwin patterns are anchored on the exact arch
   suffix.
2. **Windows carries no OS token.** linux and darwin assets spell the OS
   (`.linux.amd64`, `.darwin.arm64`); the Windows ones are
   `sops-vX.Y.Z.amd64.exe` / `sops-vX.Y.Z.arm64.exe`, so `\.exe$` is the entire
   difference between `sops-v3.13.3.amd64.exe` and `sops-v3.13.3.linux.amd64`.
   The Windows patterns are therefore shaped differently from every other
   platform's.

There is a third, version-string trap that no pattern here has to solve but any
future edit does: the raw binaries spell the version **with** a leading `v`
(`sops-v3.13.3.linux.amd64`) while the distro packages spell it **without** one
and with a different separator (`sops-3.13.3-1.aarch64.rpm`,
`sops_3.13.3_amd64.deb`). One substitution regex cannot serve both families.

Resolution was verified **both ways on every in-range release** (3.13.1,
3.13.2, 3.13.3): each of the six patterns matches exactly one asset out of 21,
every time, and no asset is claimed by two patterns. A pattern matching zero
would be silently skipped rather than reported, so this check is not optional.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `sops/mirror.yml` | hand | yes — see below |
| `sops/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `sops/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec sops/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`sops/metadata.json` declares `binaries: ["sops"]` by hand, and
`mirror-base.yml` sets `bin_scan: "off"` — forced, not preferred. Every asset
is a raw binary, so it lands at the bundle content root and `PATH` is a bare
`${installPath}`; the scan only inspects an interface-visible
`${installPath}/<dir>` entry, so with no subdirectory to point at, `auto` and
`verify` both fail spec load at exit 65 rather than offer a hollow check.

The hand list is **load-bearing beyond documentation** here: GitHub serves raw
release assets with mode `0644` (measured on every downloaded asset), and
`prepare` chmods `0755` exactly the names `metadata.json` declares. An
undeclared binary would ship non-executable, and `bin_scan: auto` could not
rescue it — the scan only reports candidates it finds *already* executable.

## Container legs provision nothing

The three Linux images are stock `ubuntu:24.04`, `alpine:3.20` and `fedora:40`
with no `containers[].setup`, and that is measured rather than assumed. sops
shells out only for PGP (`gpg`, overridable via `SOPS_GPG_EXEC`) and for
`sops edit` (`$EDITOR`); the smoke drives the **age** backend, which is
compiled into the binary. The whole sequence was replayed inside
`docker run --network none alpine:3.20` against the raw 3.13.3 asset with
`HOME` unset — encrypt exit 0, decrypt-with-key exit 0, decrypt-without-key
exit 128, `filestatus` exit 0. A bare image is the stronger claim, so nothing
is installed.

## The smoke test

`sops/tests/smoke.star` runs a complete encrypt → decrypt round trip against a
throwaway `age` keypair hardcoded in the test. age is the one sops backend that
needs neither a network service nor a second binary, which is what makes a real
round trip possible inside the sandbox.

- `sops --version` matches a version **shape** regex. `SOPS_DISABLE_VERSION_CHECK`
  is set — by default `--version` makes an HTTP call to GitHub to report whether
  the build is current, which would put a network dependency and a
  non-deterministic banner inside the smoke.
- `sops encrypt --age …` must produce a document in which the plaintext token
  appears **zero** times and sops's `ENC[AES256_GCM,` marker appears exactly
  twice — once for the encrypted value, once for the document MAC. Without that
  pair of assertions a tool that merely copied its input would pass.
- `sops decrypt` with the identity in `SOPS_AGE_KEY` must return the document
  **byte for byte**, not merely "contains the token".
- The negative control is the same decrypt with the key absent and `HOME`
  pointed at an empty scratch directory: it must exit **128**, sops's own
  documented `CouldNotRetrieveKey` status constant
  ([`cmd/sops/codes/codes.go`](https://github.com/getsops/sops/blob/main/cmd/sops/codes/codes.go)),
  and must not print the token. If the value had never really been encrypted,
  this would succeed.
- `sops filestatus` is asserted in **both** directions —
  `{"encrypted":true}` on the ciphertext and `{"encrypted":false}` on the
  plaintext. One direction alone would pass against a hardcoded answer.

Every assertion is an exit status sops computed or a byte-exact document it
produced; nothing asserts on prose.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md),
including the per-version Corresponding Source pointer MPL-2.0 §3.2(a)
requires. The logo is the official CNCF SOPS mark, reproduced for catalog
identification only.
