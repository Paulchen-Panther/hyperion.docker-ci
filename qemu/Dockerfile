ARG QEMU_VERSION=11.1.1

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS passthrough

RUN mkdir -p /out && \
    printf '#!/bin/sh\nexec "$@"\n' > /out/qemu-static && \
    chmod +x /out/qemu-static

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS raspbian-base

RUN --security=insecure \
     apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gpgv xz-utils debootstrap qemu-user-static binfmt-support && \
     update-binfmts --enable qemu-arm || true && \
     curl -fsSL "https://archive.raspbian.org/raspbian/pool/main/r/raspbian-archive-keyring/raspbian-archive-keyring_20120528.4_all.deb" -o /tmp/r.deb && \
     dpkg-deb -x /tmp/r.deb /tmp/r-key && \
     debootstrap --keyring=/tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg --arch="armhf" --variant="minbase" "bookworm" /tmp/rootfs "http://archive.raspbian.org/raspbian/" && \
     install -D -m644 /tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg /tmp/rootfs/etc/apt/trusted.gpg.d/raspbian-archive-keyring.gpg && \
     rm -rf /tmp/r.deb /tmp/r-key

FROM scratch AS base-armv6
COPY --from=raspbian-base /tmp/rootfs /

FROM ubuntu:22.04 AS base-armv7
FROM ubuntu:24.04 AS base-arm64
FROM debian:bookworm-slim AS base-amd64

FROM base-${TARGETARCH}${TARGETVARIANT} AS qemu-build

ARG QEMU_VERSION
ARG TARGETARCH
ARG TARGETVARIANT

COPY --from=passthrough /out/qemu-static /out/qemu-static
WORKDIR /src
COPY patches/ /patches/

RUN if [ "${TARGETARCH}" != "amd64" ]; then \
     apt-get update && apt-get install -y --no-install-recommends \
          build-essential \
          ninja-build \
          pkg-config \
          patch \
          curl \
          ca-certificates \
          xz-utils \
          python3 \
          python3-venv \
          python3-pip \
          python3-tomli \
          libglib2.0-dev \
          libpcre2-dev \
          zlib1g-dev && \
     case "${TARGETARCH}${TARGETVARIANT}" in \
          armv6|armv7) TARGETS="arm-linux-user" ;; \
          arm64)       TARGETS="aarch64-linux-user" ;; \
          *) exit 1 ;; \
     esac && \
     curl -fsSLO "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" && \
     tar -xf "qemu-${QEMU_VERSION}.tar.xz" && \
     rm "qemu-${QEMU_VERSION}.tar.xz" && \
     cd "qemu-${QEMU_VERSION}" && \
     if ls /patches/*.patch >/dev/null 2>&1; then \
          for patch in /patches/*.patch; do \
               patch -p1 --no-backup-if-mismatch < "$patch" || exit 1; \
          done; \
     fi && \
     mkdir /build && cd /build && \
     "/src/qemu-${QEMU_VERSION}/configure" \
          --static \
          --target-list=${TARGETS} \
          --disable-system \
          --disable-tools \
          --disable-docs \
          --disable-guest-agent \
          --disable-plugins \
          --disable-download && \
     ninja -j"$(nproc)" && \
     mkdir /out && \
     for f in /build/qemu-*; do \
          [ -x "$f" ] || continue; \
          base=$(basename "$f"); \
          strip -o "/out/${base}" "$f"; \
          cp "/out/${base}" "/out/qemu-static"; \
     done && \
     test -n "$(ls -A /out)"; \
fi

FROM scratch AS qemu
COPY --from=qemu-build /out/ /qemu/