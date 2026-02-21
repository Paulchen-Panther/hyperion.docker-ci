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

Each image contains an armhf (linux/arm/v7) Raspbian rootfs built directly from
`http://raspbian.raspberrypi.org/raspbian/` via `debootstrap`, packaged as a
compressed tar archive and added to a `FROM scratch` Docker image.

### How the workflow works

The [`.github/workflows/raspbian.yml`](.github/workflows/raspbian.yml) workflow:
1. Installs `debuerreotype`, `debootstrap`, `qemu-user-static`, and
   `raspbian-archive-keyring` on the runner.
2. Registers ARM binfmt handlers via `docker/setup-qemu-action` so that the
   debootstrap second-stage (which executes armhf binaries) works on the x86-64
   runner.
3. Runs [`scripts/build-raspbian.sh`](scripts/build-raspbian.sh) for each suite
   in the matrix (`bullseye`, `bookworm`).
4. Pushes the resulting image to GHCR using `GITHUB_TOKEN`.

The workflow triggers on every push to `master`, on a weekly schedule
(Sundays at 02:00 UTC), and can be triggered manually via `workflow_dispatch`.

### Running the script locally

Install the required packages:

```bash
sudo apt-get install -y \
  debuerreotype debootstrap gnupg \
  qemu-user-static raspbian-archive-keyring
```

Register the ARM binfmt handler (needed for debootstrap second stage):

```bash
sudo update-binfmts --enable qemu-arm
```

Build a Raspbian image:

```bash
./scripts/build-raspbian.sh bullseye
# or for bookworm:
./scripts/build-raspbian.sh --arch armhf bookworm
```

The script produces a local Docker image tagged `raspbian:<suite>` with
`linux/arm/v7` platform metadata.