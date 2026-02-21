#!/usr/bin/env bash
#
# Build a standalone Raspbian Docker image using debuerreotype.
#
# The resulting image is built FROM scratch with the Raspbian rootfs tarball
# and tagged as raspbian:<suite> with linux/arm/v6 platform metadata.
#
# Usage:
#   build-raspbian.sh [--arch <arch>] <suite>
#
# Arguments:
#   --arch <arch>  Target architecture (default: armhf)
#   suite          Raspbian suite name (e.g. bullseye, bookworm)
#
# Required system packages (install via apt-get):
#   debuerreotype debootstrap gnupg qemu-user-static raspbian-archive-keyring
#
# Example:
#   sudo apt-get install -y debuerreotype debootstrap gnupg \
#       qemu-user-static raspbian-archive-keyring
#   ./scripts/build-raspbian.sh bullseye

set -eo pipefail

ARCH="armhf"
SUITE=""
MIRROR="http://raspbian.raspberrypi.org/raspbian/"
KEYRING="/usr/share/keyrings/raspbian-archive-keyring.gpg"

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [--arch <arch>] <suite>

Build a Raspbian Docker image (FROM scratch) using debuerreotype.

Options:
  --arch <arch>  Target architecture (default: armhf)
  --help         Show this help message

Arguments:
  suite  Raspbian suite name (e.g. bullseye, bookworm)

The resulting Docker image is tagged as raspbian:<suite> with
linux/arm/v6 platform metadata set via Docker Buildx.

Examples:
  $(basename "$0") bullseye
  $(basename "$0") --arch armhf bookworm
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --help | -h)
            usage
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage
            ;;
        *)
            SUITE="$1"
            shift
            ;;
    esac
done

if [[ -z "$SUITE" ]]; then
    echo "Error: suite argument is required" >&2
    usage
fi

# Verify required commands are available
for cmd in debuerreotype-init debuerreotype-minimizing-config debuerreotype-tar docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is not installed" >&2
        echo "Install build dependencies: sudo apt-get install -y debuerreotype debootstrap gnupg qemu-user-static raspbian-archive-keyring" >&2
        exit 1
    fi
done

# Verify the Raspbian keyring is present
if [[ ! -f "$KEYRING" ]]; then
    echo "Error: Raspbian archive keyring not found at $KEYRING" >&2
    echo "Install it: sudo apt-get install -y raspbian-archive-keyring" >&2
    exit 1
fi

# Create a temporary working directory; always clean up on exit
WORKDIR="$(mktemp -d /tmp/raspbian-build.XXXXXXXX)"
ROOTFS="$WORKDIR/rootfs"
OUTPUT_TAR="$WORKDIR/rootfs.tar.xz"

cleanup() {
    sudo rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "==> Building Raspbian $SUITE ($ARCH) rootfs..."

# Initialize the Raspbian rootfs via debuerreotype (wraps debootstrap).
# Requires binfmt_misc QEMU handlers to be registered so that the debootstrap
# second stage (which executes ARM binaries) works on x86_64 hosts.
# On GitHub Actions this is handled by docker/setup-qemu-action.
# Locally, install qemu-user-static and run: sudo update-binfmts --enable qemu-arm
sudo debuerreotype-init \
    --arch "$ARCH" \
    --keyring "$KEYRING" \
    "$ROOTFS" \
    "$SUITE" \
    "$MIRROR"

# Apply debuerreotype's minimizing configuration to reduce image size
# (excludes docs, man pages, and locale data via dpkg/apt config)
sudo debuerreotype-minimizing-config "$ROOTFS"

echo "==> Creating rootfs tarball: $OUTPUT_TAR"

# Package the rootfs into a compressed tar archive
sudo debuerreotype-tar "$ROOTFS" "$OUTPUT_TAR"

# Return ownership of the tarball to the current user so Docker can read it
sudo chown "$(id -u):$(id -g)" "$OUTPUT_TAR"

# Locate the Raspbian Dockerfile relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKERFILE="$REPO_ROOT/raspbian/Dockerfile"

echo "==> Building Docker image: raspbian:$SUITE (platform linux/arm/v6)"

# Build the Docker image using FROM scratch + ADD rootfs.tar.xz /.
# --platform linux/arm/v6 embeds the correct architecture metadata in the
# image manifest so Docker on ARMv6 devices (Raspberry Pi Zero/1) pulls it correctly.
docker buildx build \
    --platform "linux/arm/v6" \
    --file "$DOCKERFILE" \
    --tag "raspbian:$SUITE" \
    --load \
    "$WORKDIR"

echo "==> Successfully built raspbian:$SUITE"
