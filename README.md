# Docker Hyperion compilation
[![Docker CI](https://github.com/Hyperion-Project/hyperion.docker-ci/workflows/Docker%20CI/badge.svg)](https://github.com/orgs/hyperion-project/packages)<br>
Provides multi platform images to compile Hyperion inside a Docker container.<br>
Images are available at https://github.com/orgs/hyperion-project/packages

## Raspbian standalone images

Standalone Raspbian base images are built from scratch using
[debuerreotype](https://github.com/debuerreotype/debuerreotype) and published to
GHCR under `ghcr.io/paulchen-panther/raspbian:<suite>`.

| Suite | Tag |
|-------|-----|
| Bullseye (Raspbian 11) | `ghcr.io/paulchen-panther/raspbian:bullseye` |
| Bookworm (Raspbian 12) | `ghcr.io/paulchen-panther/raspbian:bookworm` |

Each image contains an armhf (linux/arm/v6) Raspbian rootfs built directly from
`http://raspbian.raspberrypi.org/raspbian/` via `debootstrap`, packaged as a
compressed tar archive and added to a `FROM scratch` Docker image.

These images are built automatically as part of the `debian-armv6` build in the
[Package Repository](.github/workflows/package.yml) workflow: whenever a Debian
`armv6` image is requested, the Raspbian base image for that suite is built and
pushed first, then used as the `FROM` base in the `debian-armv6` Dockerfile.