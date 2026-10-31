ARG QT_VERSION=6.12.0
ARG CMAKE_IMAGE=ghcr.io/paulchen-panther/hyperion.docker-ci/cmake:latest

FROM ${CMAKE_IMAGE} AS cmake-image

# armv6 (Raspbian Bookworm) (glibc 2.36)
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS raspbian-base

RUN --security=insecure \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gpgv xz-utils debootstrap qemu-user-static binfmt-support && \
    curl -fsSL "https://archive.raspbian.org/raspbian/pool/main/r/raspbian-archive-keyring/raspbian-archive-keyring_20120528.4_all.deb" -o /tmp/r.deb && \
    dpkg-deb -x /tmp/r.deb /tmp/r-key && \
    debootstrap --keyring=/tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg --arch="armhf" --variant="minbase" "bookworm" /tmp/rootfs "http://archive.raspbian.org/raspbian/" && \
    install -D -m644 /tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg /tmp/rootfs/etc/apt/trusted.gpg.d/raspbian-archive-keyring.gpg && \
    rm -rf /tmp/r.deb /tmp/r-key

FROM scratch AS base-armv6
COPY --from=raspbian-base /tmp/rootfs /

# armv7, amd64, arm64 (Ubuntu 22.04) (glibc 2.35)
FROM ubuntu:22.04 AS base-armv7
FROM ubuntu:22.04 AS base-amd64
FROM ubuntu:22.04 AS base-arm64

# ------------------------------------------
# Stage 3: Build Qt
# ------------------------------------------
FROM base-${TARGETARCH}${TARGETVARIANT} AS qt-build

ARG QT_VERSION
ARG QT_PREFIX=/opt/qt6
# Additional Modules (after qtbase), e.g. "qtserialport qtwebsockets"
ARG QT_MODULES="qtserialport"
# Additional qtbase configure options, e.g. more -no-feature-*
ARG QT_EXTRA_ARGS=""
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends build-essential ninja-build perl python3 pkg-config ca-certificates curl xz-utils libssl-dev zlib1g-dev && rm -rf /var/lib/apt/lists/*

# CMake
RUN --mount=type=bind,from=cmake-image,source=/cmake,target=/tmp/cmake sh /tmp/cmake/cmake-*.sh --skip-license --prefix=/usr/local

# Download
WORKDIR /src
RUN set -eux; \
    base="https://download.qt.io/archive/qt/${QT_VERSION%.*}/${QT_VERSION}/submodules"; \
    for m in qtbase ${QT_MODULES}; do \
        curl -fsSLO "${base}/${m}-everywhere-src-${QT_VERSION}.tar.xz"; \
        tar -xf "${m}-everywhere-src-${QT_VERSION}.tar.xz"; \
        rm "${m}-everywhere-src-${QT_VERSION}.tar.xz"; \
    done

# qtbase
RUN set -eux; \
    mkdir -p /build/qtbase && cd /build/qtbase; \
    /src/qtbase-everywhere-src-${QT_VERSION}/configure \
        -prefix "${QT_PREFIX}" \
        -release \
        -cmake-generator Ninja \
        -no-dbus -no-gui -no-widgets -no-icu \
        -openssl-linked -qt-pcre -qt-zlib \
        -no-feature-brotli -no-feature-gssapi -no-feature-ocsp \
        -no-feature-animation -no-feature-testlib \
        -nomake tests -nomake examples \
        ${QT_EXTRA_ARGS}; \
    cmake --build . --parallel "$(nproc)"; \
    cmake --install .

# Additional Modules
RUN set -eux; \
    for m in ${QT_MODULES}; do \
        mkdir -p "/build/${m}" && cd "/build/${m}"; \
        cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="${QT_PREFIX}" \
            -DCMAKE_INSTALL_PREFIX="${QT_PREFIX}" \
            -DBUILD_TESTING=OFF -DQT_BUILD_EXAMPLES=OFF \
            "/src/${m}-everywhere-src-${QT_VERSION}"; \
        cmake --build . --parallel "$(nproc)"; \
        cmake --install .; \
    done; \
    find "${QT_PREFIX}" -type f \( -name '*.so*' -o -path '*/bin/*' \) -exec strip --strip-unneeded {} + 2>/dev/null || true

FROM scratch AS qt
COPY --from=qt-build /opt/qt6/ /qt/