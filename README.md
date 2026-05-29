# Yocto CM4 Build Environment

Dockerised Yocto Scarthgap (5.0 LTS) build environment for the Raspberry Pi Compute Module 4.

Produces a `core-image-base` with OpenSSH and networking tools pre-installed.

## Requirements

- Docker Engine + Docker Compose (v2) on Ubuntu 22.04 or later
- ~80 GB free disk space (60 GB build + 20 GB download cache)
- 8+ GB RAM recommended

## Project layout

```
yocto-cm4/
├── Dockerfile               # Ubuntu 22.04 + Yocto Scarthgap host dependencies
├── docker-compose.yml       # Mounts workspace, downloads, and sstate-cache
├── .env                     # HOST_UID / HOST_GID — match to your user
├── scripts/
│   ├── entrypoint.sh        # Container entrypoint
│   └── setup.sh             # One-time layer clone + config install
├── conf/
│   ├── local.conf           # MACHINE, image features, cache dirs
│   └── bblayers.conf        # Layer list
├── workspace/               # Yocto source tree and build output (large)
├── downloads/               # Shared download cache (DL_DIR)
└── sstate-cache/            # Shared state cache (SSTATE_DIR)
```

## Workflow

### 1. Configure user IDs

Check your UID and GID, then update `.env` if they are not `1000`:

```bash
id -u && id -g
# Edit .env: HOST_UID=<uid>  HOST_GID=<gid>
```

This ensures files written into the bind-mounted volumes are owned by your
host user rather than root.

### 2. Build the container image

```bash
docker compose build
```

### 3. Clone all Yocto layers (one-time)

This clones `poky`, `meta-openembedded`, and `meta-raspberrypi` into
`./workspace` and installs the CM4 configuration files.

```bash
docker compose run --rm yocto-builder /opt/yocto/scripts/setup.sh
```

Expect 10–15 minutes depending on your connection.

### 4. Enter an interactive build shell

```bash
docker compose run --rm -it yocto-builder
```

### 5. Initialise the BitBake environment

Run this every time you open a new shell inside the container. It sets up
`PATH` so that `bitbake` and related tools are available.

```bash
source poky/oe-init-build-env build
```

### 6. Build the image

```bash
bitbake core-image-base
```

First run takes 1–3 hours depending on CPU core count. Subsequent builds
complete in minutes thanks to the shared state cache.

### 7. Find the output

```
workspace/build/tmp/deploy/images/raspberrypi4-64/
```

The flashable image is the `.wic.bz2` file. Decompress and write it to an
SD card or eMMC:

```bash
# SD card
bzcat core-image-base-raspberrypi-cm4.rootfs.wic.bz2 | sudo dd of=/dev/sdX bs=4M status=progress

# eMMC (CM4 with eMMC)
# Use rpiboot + usbboot — see https://www.raspberrypi.com/documentation/computers/compute-module.html
```

## Key things to know

### WiFi / Bluetooth firmware

The CM4 uses a CYW43455 chip whose firmware requires accepting a Synaptics
licence. It is excluded by default. To include it, uncomment this line in
`conf/local.conf`:

```
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"
```

Then add `linux-firmware-rpidistro-bcm43455` to `IMAGE_INSTALL:append`.

### SSH access

Root login with no password is enabled via the `debug-tweaks` image feature.
Remove it for production images:

```
# conf/local.conf
EXTRA_IMAGE_FEATURES ?= ""
```

### Speeding up rebuilds

The `sstate-cache/` directory is the biggest lever for build speed. Do not
delete it between runs. If you have multiple Yocto projects on the same
machine, point all of them at the same `SSTATE_DIR` to share cached
artifacts across projects.

### eMMC vs SD card

The same image works on both CM4 variants. Flashing differs:

- **SD card CM4**: write the `.wic.bz2` image directly with `dd` or Raspberry Pi Imager.
- **eMMC CM4**: boot the module in USB slave mode with `rpiboot`, then flash
  via `usbboot`. See the [official CM4 documentation](https://www.raspberrypi.com/documentation/computers/compute-module.html).

### Serial console

UART is enabled by default (`ENABLE_UART = "1"` in `local.conf`). Connect a
3.3 V USB-to-UART adapter to GPIO14 (TX) and GPIO15 (RX) on the CM4 carrier
board and open a terminal at 115200 baud.

### Disk space

| Directory      | Typical size | Purpose                          |
|----------------|-------------|----------------------------------|
| `workspace/`   | 40–60 GB    | Build tree, object files, packages |
| `downloads/`   | 10–20 GB    | Downloaded source archives       |
| `sstate-cache/`| 5–15 GB     | Cached build artefacts           |

### Parallelism

`BB_NUMBER_THREADS` and `PARALLEL_MAKE` in `local.conf` default to the
container's CPU count. On a shared machine you may want to cap them:

```
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"
```

## Adding packages

Append packages to `IMAGE_INSTALL` in `conf/local.conf`:

```
IMAGE_INSTALL:append = " htop nano python3"
```

Search for available recipes with:

```bash
bitbake-layers show-recipes | grep <name>
```

## Customising the kernel

```bash
# Inside the container, with build env sourced:
bitbake linux-raspberrypi -c menuconfig
bitbake linux-raspberrypi -c savedefconfig
```

The saved defconfig lands in `workspace/build/tmp/work/raspberrypi_cm4-poky-linux/linux-raspberrypi/`.
