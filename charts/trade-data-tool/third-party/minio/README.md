# MinIO, built from final source

The object store bundled with the Trade Data Tool chart (image `tdt/minio`).
`minio/minio` is archived and publishes no images or fixes, so Trade Data
Tool's CI builds the final commit of its `master` branch,
[`7aac2a2c5b7c882e68c1ce017d8256be2feea27f`](https://github.com/minio/minio/tree/7aac2a2c5b7c882e68c1ce017d8256be2feea27f)
(2026-02-12), with newer dependency versions and one security patch.

## What this patch changes

Two things, both in this directory: `go.mod` and `go.sum`, which replace
upstream's at build time, and one source patch in `patches/`, applied with
`git apply` before the build (see the `Dockerfile`).

- `patches/0001-refuse-unsigned-trailer-uploads.patch` removes the
  unsigned-trailer upload mode (`X-Amz-Content-Sha256:
  STREAMING-UNSIGNED-PAYLOAD-TRAILER`) from the S3 authentication types the
  server accepts. Such requests are refused before authentication or any S3
  handler runs, with HTTP 400 `InvalidRequest` ("The authorization mechanism
  you have provided is not supported"). This is upstream's own advisory
  workaround for CVE-2026-40344 and CVE-2026-41145, which were fixed only
  after `minio/minio` was archived. Signed uploads, including the signed trailer variant
  `STREAMING-AWS4-HMAC-SHA256-PAYLOAD-TRAILER`, presigned URLs and multipart
  uploads are unaffected. The patch adds a test case asserting the refusal.

- `go.mod`/`go.sum`: every module with a fixed vulnerability in code the server calls
  (`govulncheck -mode=binary`) is bumped to a fixed version: 11 direct and
  39 indirect version bumps, nothing added, removed or downgraded. The rest
  of the diff is what Go's minimal version selection pulls in with them.
- The `go` directive rises from 1.24.0 to 1.26.0 because some bumped modules
  require it. That also changes Go's default `GODEBUG` settings. The one with
  a visible effect: `GOMAXPROCS` now follows the container's CPU limit instead
  of the node's core count. The TLS-related defaults don't apply, because this
  MinIO serves plain HTTP behind the ingress.
- Because `go.mod` and `go.sum` differ from upstream's, the binary's module
  version reads `v0.0.0-20260212201848-7aac2a2c5b7c+dirty`. That's expected.

## Toolchain and version

`golang:1.27` (`GOTOOLCHAIN=local`), `CGO_ENABLED=0`, `-trimpath`, using
upstream's `buildscripts/gen-ldflags.go` with `MINIO_HOTFIX=tdt<N>`, where `N` is
the Dockerfile's `TDT_PATCH_LEVEL` (bumped whenever `patches/`, `go.mod` or
`go.sum` change). So `minio --version` reports
`DEVELOPMENT.2026-02-12T20-18-48Z.tdt1` and the commit, never a `RELEASE` tag,
and a running pod says exactly which build it is. The image holds the `minio` binary only, on
distroless static, running as uid 1000.

## Known vulnerabilities without an upstream fix

Upstream publishes no fix for these in the open-source code (GitHub advisory
database: affected up to and including the commit above; CVE-2026-39414's range
is open-ended).

| ID | Severity | Applies to this chart's setup? |
|---|---|---|
| CVE-2026-33322 | CRITICAL | No. Needs OIDC login, which the chart never configures. |
| CVE-2026-33419 | CRITICAL | No. Needs LDAP login, which the chart never configures. |
| CVE-2026-40344 | HIGH | Mitigated by `patches/0001`: the affected request mode is refused. |
| CVE-2026-41145 | HIGH | Mitigated by `patches/0001`: the affected request mode is refused. |
| CVE-2026-34204 | HIGH | Only for authenticated users who can write objects. |
| CVE-2026-39414 | HIGH | Only for authenticated users of S3 Select. |
| CVE-2026-42600 | MEDIUM | No. Internode storage API, registered only in distributed (multi-node) mode; the chart runs a single node. |
| GO-2026-5932 | (advisory) | Deprecated `golang.org/x/crypto/openpgp`, still imported by a dependency. |

Never enable OIDC or LDAP identity on this MinIO. The chart sets only the
root credentials.

This list is a lower bound: it covers published advisories, and not every
advisory reaches the scanners (CVE-2026-42600 isn't reported by Trivy). The
same statuses are in `openvex.json` (OpenVEX), which ships in the image at
`/usr/share/doc/minio/openvex.json`; Trade Data Tool's CI scans the image with
`trivy --vex openvex.json`.

## Fixable findings left at upstream's versions

Trivy also reports fixable HIGH findings in `github.com/apache/thrift` v0.21.0
and `github.com/prometheus/prometheus` v0.303.0. They stay at upstream's
versions because `govulncheck` finds no use of their vulnerable code in this
binary: `prometheus` is in the build list, but its vulnerable packages aren't
imported, and no Go vulnerability database entry matches `thrift`'s use.
Bumping `prometheus` would also add new modules to the build.

## Source and license

MinIO is licensed under AGPL-3.0. The complete corresponding source of this
build is the upstream commit linked above plus this directory (`go.mod`,
`go.sum`, `patches/`, and the `Dockerfile`, which holds the exact build steps).
`openvex.json` is documentation, not source.
