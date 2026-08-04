# NOTICE

This repository packages and redistributes upstream software published by the
[getsops project](https://github.com/getsops). The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

Each package's logo is reproduced for catalog identification only, under
nominative fair use. The marks remain the property of their respective owners
and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `sops` | `ghcr.io/ocx-contrib/getsops/sops` | `MPL-2.0` |

---

## `sops`

Upstream: <https://github.com/getsops/sops>
Published to `ghcr.io/ocx-contrib/getsops/sops`.

| Component | SPDX | Holder |
|---|---|---|
| sops (`sops`) | **MPL-2.0** | Mozilla Foundation and the sops contributors |

Weak (file-level) copyleft. MPL-2.0 §3.2 grants redistribution of the
executable form, and its share-alike duty attaches to **modified MPL-covered
source files** — of which this mirror has none: upstream's own release binaries
are republished unchanged, byte for byte. The terms are those of
<https://github.com/getsops/sops/blob/main/LICENSE>.

**Corresponding source, per version.** MPL-2.0 §3.2(a) requires that recipients
of the executable form be informed how to obtain the Source Code Form. Every
mirrored release is a tag in the upstream GitHub repository, so for any mirrored
version `X.Y.Z` the source is at:

- <https://github.com/getsops/sops/releases/tag/vX.Y.Z> — the release tag, which
  is also what the mirrored binaries were built from
- <https://github.com/getsops/sops/tree/vX.Y.Z> — the tagged source tree,
  including the `Makefile` and `.goreleaser.yaml` that produce these artifacts

Concretely, for the versions this mirror currently carries:

| Version | Source |
|---|---|
| `3.13.1` | <https://github.com/getsops/sops/releases/tag/v3.13.1> |
| `3.13.2` | <https://github.com/getsops/sops/releases/tag/v3.13.2> |
| `3.13.3` | <https://github.com/getsops/sops/releases/tag/v3.13.3> |

The sops name is used for catalog identification under nominative fair use. The
logo shipped with this package is the official SOPS project mark, taken from
[`cncf/artwork`](https://github.com/cncf/artwork/tree/main/projects/sops); sops
is a [CNCF](https://www.cncf.io/) project and its marks are trademarks of The
Linux Foundation, reproduced here for identification only.

sops encrypts *with* AWS KMS, GCP KMS, HuaweiCloud KMS, Azure Key Vault,
HashiCorp Vault, age and PGP, but bundles none of them: no cloud SDK binary and
no `gpg` is redistributed by this package.

---

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
