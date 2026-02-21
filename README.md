# Docker Hyperion compilation
[![Docker CI](https://github.com/Hyperion-Project/hyperion.docker-ci/workflows/Docker%20CI/badge.svg)](https://github.com/orgs/hyperion-project/packages)<br>
Provides multi platform images to compile Hyperion inside a Docker container.<br>
Images are available at https://github.com/orgs/hyperion-project/packages

## Raspbian standalone images

Standalone Raspbian base images are built from scratch using
[debuerreotype](https://github.com/debuerreotype/debuerreotype) as part of the
`debian-armv6` build. The image is built locally on the runner and used directly
as the base for `debian-armv6`; it is not pushed to any registry.