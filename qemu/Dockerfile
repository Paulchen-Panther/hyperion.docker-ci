ARG QEMU_VERSION=11.1.1

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS passthrough
RUN mkdir -p /out && \
    printf '#!/bin/sh\nexec "$@"\n' > /out/qemu-static && \
    chmod +x /out/qemu-static

FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS qemu-build

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
          zlib1g-dev \
          gcc-arm-linux-gnueabihf \
          g++-arm-linux-gnueabihf \
          gcc-aarch64-linux-gnu \
          g++-aarch64-linux-gnu && \
     case "${TARGETARCH}${TARGETVARIANT}" in \
          armv6|armv7) \
               TARGETS="arm-linux-user" \
               CROSS_PREFIX="arm-linux-gnueabihf-" \
               ;; \
          arm64) \
               TARGETS="aarch64-linux-user" \
               CROSS_PREFIX="aarch64-linux-gnu-" \
               ;; \
          *) exit 1 ;; \
     esac && \
     curl -fsSLO "https://qemu.org{QEMU_VERSION}.tar.xz" && \
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
          --cross-prefix=${CROSS_PREFIX} \
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
          ${CROSS_PREFIX}strip -o "/out/${base}" "$f"; \
          cp "/out/${base}" "/out/qemu-static"; \
     done && \
     test -n "$(ls -A /out)"; \
fi

FROM scratch AS qemu
COPY --from=qemu-build /out/ /qemu/
