ARG BASE_IMAGE=ubuntu:20.04
ARG CMAKE_VERSION=4.4.3

# raspbian-rootfs (only built when BASE_IMAGE=raspbian)
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS raspbian-rootfs
RUN --security=insecure \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gpgv xz-utils debootstrap qemu-user-static && \
    curl -fsSL "https://archive.raspbian.org/raspbian/pool/main/r/raspbian-archive-keyring/raspbian-archive-keyring_20120528.4_all.deb" -o /tmp/r.deb && \
    dpkg-deb -x /tmp/r.deb /tmp/r-key && \
    STAGING_SUITES=$(curl -fsSL "http://archive.raspbian.org/raspbian/dists/bookworm/Release" -o /tmp/release && { grep -qx "Suite: testing" /tmp/release && echo "--extra-suites=${RASPBIAN_SUITE}-staging" || true; }) && \
    debootstrap --keyring=/tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg --arch="armhf" --variant="minbase" ${STAGING_SUITES} "${RASPBIAN_SUITE}" /tmp/rootfs "http://archive.raspbian.org/raspbian/" && \
    install -D -m644 /tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg /tmp/rootfs/etc/apt/trusted.gpg.d/raspbian-archive-keyring.gpg && \
    rm -rf /tmp/r.deb /tmp/r-key
 
FROM scratch AS raspbian
COPY --from=raspbian-rootfs /tmp/rootfs /

FROM ${BASE_IMAGE} AS base

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
    autotools-dev \
    build-essential \
    ca-certificates \
    curl \
    patch \
    perl \
    xz-utils

FROM base AS deps

# Curses (official: ncurses 6.1, static). -fPIC because Ubuntu's GCC links PIE
# by default; config.guess/sub refreshed so newer CPUs (riscv64) are recognized.
RUN mkdir -p /opt/ncurses/src/ncurses-build && cd /opt/ncurses/src \
    && curl -fsSLO https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.1.tar.gz \
    && tar xzf ncurses-6.1.tar.gz \
    && cp /usr/share/misc/config.guess /usr/share/misc/config.sub ncurses-6.1/ \
    && cd ncurses-build \
    && CFLAGS="-O2 -fPIC" ../ncurses-6.1/configure \
        --prefix=/opt/ncurses \
        --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo \
        --with-default-terminfo-dir=/usr/share/terminfo \
        --without-shared \
    && make -j "$(nproc)" \
    && make install.libs install.includes \
    && cd /opt \
    && rm -rf /opt/ncurses/src

# OpenSSL (official: 3.6.0, static, same flags and patch; plus -fPIC for PIE)
COPY <<"EOT" /opt/openssl/src/openssl-source.patch
# enable pthread APIs disabled by our _POSIX_SOURCE definitions
--- openssl-source/crypto/threads_pthread.c.orig
+++ openssl-source/crypto/threads_pthread.c
@@ -6,6 +6,8 @@
  * in the file LICENSE in the source distribution or at
  * https://www.openssl.org/source/license.html
  */
+#undef _POSIX_C_SOURCE
+#undef _POSIX_SOURCE

 /* We need to use the OPENSSL_fork_*() deprecated APIs */
 #define OPENSSL_SUPPRESS_DEPRECATED
EOT

RUN cd /opt/openssl/src \
    && curl -fsSLO https://github.com/openssl/openssl/releases/download/openssl-3.6.0/openssl-3.6.0.tar.gz \
    && tar xzf openssl-3.6.0.tar.gz \
    && cd openssl-3.6.0 \
    && patch -p1 -i ../openssl-source.patch \
    && ./Configure --prefix=/opt/openssl linux-elf no-asm no-shared -fPIC -D_POSIX_C_SOURCE=199506L -D_POSIX_SOURCE=1 -D_SVID_SOURCE=1 -D_BSD_SOURCE=1 \
    && make install_dev -j "$(nproc)" \
    && cd /opt \
    && rm -rf /opt/openssl/src

# CMake source
FROM base AS src
ARG CMAKE_VERSION
RUN mkdir -p /opt/cmake/src/cmake && cd /opt/cmake/src \
    && curl -fsSLO "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz" \
    && tar xzf "cmake-${CMAKE_VERSION}.tar.gz" -C cmake --strip-components=1 \
    && rm -f "cmake-${CMAKE_VERSION}.tar.gz"

# CMake build
FROM deps AS build
ARG TARGETPLATFORM
ARG TEST=false

COPY --from=src /opt/cmake/src/cmake /opt/cmake/src/cmake

RUN case "${TARGETPLATFORM:-linux/amd64}" in \
        linux/amd64)   PKG_ARCH=x86_64  ;; \
        linux/arm64)   PKG_ARCH=aarch64 ;; \
        linux/arm/v7)  PKG_ARCH=armv7   ;; \
        linux/arm/v6)  PKG_ARCH=armv6   ;; \
        linux/riscv64) PKG_ARCH=riscv64 ;; \
        *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" >&2; exit 1 ;; \
    esac \
 && echo "Package arch: ${PKG_ARCH}" \
 && mkdir -p /opt/cmake/src/cmake-build \
 && cd /opt/cmake/src/cmake-build \
 # Official cache.txt: drop the Qt/cmake-gui parts, set the package name.
 && sed -e '/^# Enable cmake-gui/,/^$/d' \
        -e '/^# Skip Qt5 tests/,/^$/d' \
        -e "s/^CPACK_SYSTEM_NAME.*/CPACK_SYSTEM_NAME:STRING=linux-${PKG_ARCH}/" \
        /opt/cmake/src/cmake/Utilities/Release/linux/x86_64/cache.txt > CMakeCache.txt \
 # libatomic: needed if 1/2/8-byte atomics are not native (riscv64, armv6).
 # Link it statically at the end of the link line to keep the package portable.
 && printf '%s\n' \
        '#include <atomic>' \
        '#include <cstdint>' \
        'std::atomic<std::uint8_t> a8;' \
        'std::atomic<std::uint16_t> a16;' \
        'std::atomic<std::uint64_t> a64;' \
        'int main() { ++a8; ++a16; ++a64; return 0; }' > /tmp/atomic.cpp \
 && BOOT_LDFLAGS="" \
 && if g++ -O0 /tmp/atomic.cpp -o /tmp/atomic-test; then \
        echo "libatomic: not needed"; \
    elif g++ -O0 /tmp/atomic.cpp -o /tmp/atomic-test -Wl,-Bstatic -latomic -Wl,-Bdynamic; then \
        echo "libatomic: linking statically"; \
        printf '\n# libatomic (no native 1/2/8-byte atomics on this CPU)\n' >> CMakeCache.txt; \
        printf 'CMAKE_C_STANDARD_LIBRARIES:STRING=-Wl,-Bstatic -latomic -Wl,-Bdynamic\n' >> CMakeCache.txt; \
        printf 'CMAKE_CXX_STANDARD_LIBRARIES:STRING=-Wl,-Bstatic -latomic -Wl,-Bdynamic\n' >> CMakeCache.txt; \
        BOOT_LDFLAGS="-Wl,--no-as-needed -latomic"; \
    else \
        echo "ERROR: atomics need libatomic, but static libatomic.a cannot be linked" >&2; exit 1; \
    fi \
 && cat CMakeCache.txt \
 # Same steps as the official release Dockerfile.
 # (BOOT_LDFLAGS only affects the temporary bootstrap cmake, which is not shipped.)
 && set -x \
 && LDFLAGS="${BOOT_LDFLAGS}" ../cmake/bootstrap --parallel="$(nproc)" --docdir=doc/cmake \
 && nice make -j "$(nproc)" \
 && if [ "${TEST}" = "true" ]; then \
        bin/ctest --output-on-failure -j 8 \
            -R '^(CMake\.|CMakeLib\.|RunCMake\.ctest_memcheck)'; \
    fi \
 && bin/cpack -G TGZ \
 && bin/cpack -G STGZ \
 && set +x \
 # Portability checks: no dynamic C++/gcc/atomic runtime, report glibc floor.
 && readelf -d bin/cmake | grep NEEDED \
 && if readelf -d bin/cmake | grep -E 'NEEDED.*(libstdc\+\+|libgcc_s|libatomic)'; then \
        echo "ERROR: bin/cmake depends on a shared compiler runtime" >&2; exit 1; \
    fi \
 && echo "Highest GLIBC symbol version: $(objdump -T bin/cmake | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -n1)" \
 # Smoke test of the self-extracting installer.
 && sh cmake-*-linux-${PKG_ARCH}.sh --skip-license --exclude-subdir --prefix=/tmp/cmake-test \
 && /tmp/cmake-test/bin/cmake --version \
 && rm -rf /tmp/cmake-test \
 && mkdir /out \
 && mv cmake-*-linux-${PKG_ARCH}.* /out \
 && ls -l /out

# ---------------------------------------------------------------------------
# out: only the packages (use with --output type=local,dest=...)
# ---------------------------------------------------------------------------
FROM scratch AS out
COPY --from=build /out/ /