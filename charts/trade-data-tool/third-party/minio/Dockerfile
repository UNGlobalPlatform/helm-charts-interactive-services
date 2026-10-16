# MinIO server for the Trade Data Tool chart's bundled object store, built from
# the FINAL source of the archived minio/minio repository. Upstream publishes no
# images or fixes any more, so we build it ourselves:
# - source: minio/minio at MINIO_COMMIT, plus the patches in patches/ (README.md
#   lists them; today one, refusing unsigned-trailer uploads);
# - dependencies: our go.mod/go.sum (this directory) replace upstream's, bumping
#   the modules that had fixed vulnerabilities (README.md lists them);
# - toolchain: a supported Go, pinned into the binary with GOTOOLCHAIN=local;
# - version: upstream's own buildscripts/gen-ldflags.go with MINIO_HOTFIX set to
#   tdt<TDT_PATCH_LEVEL>, so the binary reports DEVELOPMENT.<commit date>.tdt<N>
#   and never claims a release. Bump TDT_PATCH_LEVEL whenever patches/, go.mod or
#   go.sum change, so a running pod says which build it is.
# The image holds the minio binary only (no mc), on distroless static, as uid 1000.
FROM docker.io/library/golang:1.27-bookworm AS build
ENV GOTOOLCHAIN=local CGO_ENABLED=0
ARG MINIO_COMMIT=7aac2a2c5b7c882e68c1ce017d8256be2feea27f
ARG TDT_PATCH_LEVEL=1
RUN set -eux; \
    git init -q /src; cd /src; \
    git fetch -q --depth 1 https://github.com/minio/minio.git "$MINIO_COMMIT"; \
    git -c advice.detachedHead=false checkout -q FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "$MINIO_COMMIT"
WORKDIR /src
COPY go.mod go.sum ./
COPY patches/ /patches/
RUN set -eux; \
    git apply --verbose /patches/*.patch; \
    go mod verify; \
    ldflags="$(MINIO_HOTFIX="tdt${TDT_PATCH_LEVEL}" go run buildscripts/gen-ldflags.go)"; \
    go build -tags kqueue -trimpath -ldflags "$ldflags" -o /minio .; \
    /minio --version

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /minio /usr/bin/minio
# Machine-readable status of every known unfixed vulnerability in this build;
# CI scans the image with `trivy --vex` against the same file.
COPY openvex.json /usr/share/doc/minio/openvex.json
# The chart runs it with a read-only root filesystem and an emptyDir on /tmp;
# MinIO keeps its certs dir under $HOME/.minio.
ENV HOME=/tmp
USER 1000:1000
EXPOSE 9000 9001
ENTRYPOINT ["/usr/bin/minio"]
CMD ["server", "/data", "--console-address", ":9001"]
