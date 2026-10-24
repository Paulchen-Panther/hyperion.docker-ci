ARG CMAKE_VERSION=4.4.4

# ------------------------------------------
# Stage 1: Prebuilt binaries (amd64 / arm64)
# ------------------------------------------

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS download

ARG CMAKE_VERSION
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && \
    case "${TARGETARCH}" in \
        amd64) A=x86_64 ;; \
        arm64) A=aarch64 ;; \
        *) exit 1 ;; \
    esac && \
    mkdir /out && cd /out && \
    curl -fsSLO "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${A}.sh"

# ------------------------------------------
# Stage 2: ARM base images
# ------------------------------------------

# armv6 (Raspbian Bookworm) (glibc 2.36)
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS raspbian-base

RUN --security=insecure \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gpgv xz-utils debootstrap qemu-user-static && \
    curl -fsSL "https://archive.raspbian.org/raspbian/pool/main/r/raspbian-archive-keyring/raspbian-archive-keyring_20120528.4_all.deb" -o /tmp/r.deb && \
    dpkg-deb -x /tmp/r.deb /tmp/r-key && \
    debootstrap --keyring=/tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg --arch="armhf" --variant="minbase" "bookworm" /tmp/rootfs "http://archive.raspbian.org/raspbian/" && \
    install -D -m644 /tmp/r-key/usr/share/keyrings/raspbian-archive-keyring.gpg /tmp/rootfs/etc/apt/trusted.gpg.d/raspbian-archive-keyring.gpg && \
    rm -rf /tmp/r.deb /tmp/r-key

FROM scratch AS base-armv6
COPY --from=raspbian-base /tmp/rootfs /

# armv7 (Ubuntu 22.04) (glibc 2.35)
FROM --platform=$TARGETPLATFORM ubuntu:22.04 AS base-armv7

# ------------------------------------------
# Stage 3: CMake (ARM only)
# ------------------------------------------
FROM base-${TARGETARCH}${TARGETVARIANT} AS cmake-build

ARG CMAKE_VERSION
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /src
RUN curl -fsSLO "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz" && \
    tar -xzf "cmake-${CMAKE_VERSION}.tar.gz" --strip-components 1 && \
    mkdir /build && cd /build && \
    A="${TARGETARCH}${TARGETVARIANT}l" && \
    printf '%s\n' \
        'CMAKE_BUILD_TYPE:STRING=Release' \
        'CMAKE_C_STANDARD:STRING=11' \
        'CMAKE_CXX_STANDARD:STRING=14' \
        'CMAKE_EXE_LINKER_FLAGS:STRING=-static-libstdc++ -static-libgcc' \
        'CMAKE_CXX_STANDARD_LIBRARIES:STRING=-Wl,-Bstatic -latomic -Wl,-Bdynamic' \
        'BUILD_CursesDialog:BOOL=OFF' \
        'BUILD_QtDialog:BOOL=OFF' \
        'BUILD_TESTING:BOOL=OFF' \
        'CMake_TEST_BOOTSTRAP:BOOL=FALSE' \
        "CPACK_SYSTEM_NAME:STRING=linux-${A}" \
        > CMakeCache.txt && \
    /src/bootstrap --parallel="$(nproc)" --docdir=doc/cmake --system-curl && \
    make -j"$(nproc)" && \
    bin/cpack -G TGZ && \
    bin/cpack -G STGZ && \
    mkdir /out && \
    mv cmake-*-linux-"${A}".* /out/

# Test the compiled CMake binaries
RUN A="${TARGETARCH}${TARGETVARIANT}l" && \
    P="/tmp/test/cmake-${CMAKE_VERSION}-linux-${A}" && \
    mkdir /tmp/test && \
    sh "/out/cmake-${CMAKE_VERSION}-linux-${A}.sh" --skip-license --prefix=/tmp/test && \
    for b in cmake ctest cpack; do "${P}/bin/${b}" --version | head -n1; done

# ------------------------------------------
# Stage 5: Final image
# ------------------------------------------

FROM scratch AS cmake-arm
COPY --from=cmake-build /out/ /cmake/

FROM scratch AS cmake-amd64
COPY --from=download /out/ /cmake/

FROM scratch AS cmake-arm64
COPY --from=download /out/ /cmake/

FROM cmake-${TARGETARCH} AS cmake