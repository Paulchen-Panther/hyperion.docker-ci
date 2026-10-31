ARG REPOSITORY="paulchen-panther"
ARG QT_VERSION="6.8.4"

FROM ghcr.io/${REPOSITORY}/cmake:latest AS cmake-bin

# ------------------------------------------
# Stage 2: Base image
# ------------------------------------------

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
# Stage 3: Build Qt (shared)
# ------------------------------------------
FROM base-${TARGETARCH}${TARGETVARIANT} AS qt-build

ARG QT_VERSION
ARG QT_PREFIX=/opt/qt6
# Additional modules built after qtbase
ARG QT_MODULES="qtserialport qtwebsockets"
# 1 = build the xcb platform plugin (like the distro Qt), 0 = headless/offscreen
ARG QT_XCB=1
# Additional qtbase configure options, e.g. more -no-feature-*
ARG QT_EXTRA_ARGS=""
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends build-essential ninja-build perl python3 pkg-config ca-certificates curl xz-utils libssl-dev libudev-dev libxkbcommon-dev && \
    if [ "${QT_XCB}" = "1" ]; then \
        apt-get install -y --no-install-recommends \
            libfontconfig1-dev libx11-dev libx11-xcb-dev libxkbcommon-x11-dev \
            libxcb1-dev libxcb-glx0-dev libxcb-icccm4-dev libxcb-image0-dev libxcb-keysyms1-dev \
            libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev \
            libxcb-shm0-dev libxcb-sync-dev libxcb-util-dev libxcb-xfixes0-dev \
            libxcb-xinerama0-dev libxcb-xinput-dev libxcb-xkb-dev libxcb-cursor-dev; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Install CMake
RUN --mount=type=bind,from=cmake-bin,source=/cmake,target=/mnt/cmake sh /mnt/cmake/cmake-*.sh --skip-license --prefix=/usr/local --exclude-subdir

# Download sources
WORKDIR /src
RUN base="https://download.qt.io/archive/qt/${QT_VERSION%.*}/${QT_VERSION}/submodules" && \
    for m in qtbase ${QT_MODULES}; do \
        curl -fsSLO "${base}/${m}-everywhere-src-${QT_VERSION}.tar.xz" && \
        tar -xf "${m}-everywhere-src-${QT_VERSION}.tar.xz" && \
        rm "${m}-everywhere-src-${QT_VERSION}.tar.xz" || exit 1; \
    done

# Build qtbase
RUN if [ "${QT_XCB}" = "1" ]; then \
        PLATFORM_ARGS="-xcb -xcb-xlib -fontconfig"; \
    else \
        PLATFORM_ARGS="-no-xcb -no-fontconfig -qpa offscreen"; \
    fi && \
    mkdir -p /build/qtbase && cd /build/qtbase && \
    /src/qtbase-everywhere-src-${QT_VERSION}/configure \
        -prefix "${QT_PREFIX}" \
        -release \
        -nomake tests -nomake examples \
        -no-dbus -no-icu -no-glib \
        -no-opengl -no-feature-vulkan \
        -no-feature-printsupport -no-feature-cups \
        -no-feature-brotli -no-feature-gssapi -no-feature-ocsp \
        -openssl-linked \
        -qt-pcre -qt-zlib -qt-freetype -qt-harfbuzz -qt-libpng -qt-libjpeg \
        -sql-sqlite -qt-sqlite -no-sql-mysql -no-sql-odbc -no-sql-psql \
        ${PLATFORM_ARGS} ${QT_EXTRA_ARGS} && \
    cmake --build . --parallel "$(nproc)" && \
    cmake --install .

# Build additional modules and strip
RUN for m in ${QT_MODULES}; do \
        mkdir -p "/build/${m}" && cd "/build/${m}" && \
        cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="${QT_PREFIX}" \
            -DCMAKE_INSTALL_PREFIX="${QT_PREFIX}" \
            -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
            "/src/${m}-everywhere-src-${QT_VERSION}" && \
        cmake --build . --parallel "$(nproc)" && \
        cmake --install . || exit 1; \
    done && \
    (find "${QT_PREFIX}" -type f -name '*.so*' -exec strip --strip-unneeded {} + 2>/dev/null || true)

# ------------------------------------------
# Stage 4: Create the installer (STGZ)
# ------------------------------------------
FROM qt-build AS qt-package

ARG QT_VERSION
ARG QT_PREFIX=/opt/qt6
ARG TARGETARCH
ARG TARGETVARIANT

COPY installer.cmake /pkg/CMakeLists.txt

RUN mkdir -p /out && \
    case "${TARGETARCH}${TARGETVARIANT}" in \
        amd64) A=x86_64 ;; \
        arm64) A=aarch64 ;; \
        armv6|armv7) A="${TARGETARCH}${TARGETVARIANT}l" ;; \
        *) exit 1 ;; \
    esac && \
    cmake -S /pkg -B /pkg/build \
        -DQT_PREFIX="${QT_PREFIX}" \
        -DQT_VERSION="${QT_VERSION}" \
        -DQT_ARCH="${A}" \
        -DQT_SRC="/src/qtbase-everywhere-src-${QT_VERSION}" && \
    cd /pkg/build && cpack

# Sanity check
RUN mkdir /chk && \
    sh /out/qt6-*.sh --skip-license --prefix=/chk --exclude-subdir && \
    test -f /chk/lib/cmake/Qt6/Qt6Config.cmake && \
    test -L /chk/lib/libQt6Core.so.6 && \
    rm -rf /chk

# ------------------------------------------
# Stage 5: Final image
# ------------------------------------------
FROM scratch AS qt6
COPY --from=qt-package /out/qt6-*.sh /qt6/