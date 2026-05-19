#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# setup.sh — run once inside the container to clone all required layers
#            and install the CM4 configuration files.
#
# Usage (from the host):
#   docker compose run --rm yocto-builder /opt/yocto/scripts/setup.sh
#
# After this script completes, enter the container interactively and build:
#   docker compose run --rm -it yocto-builder
#   source poky/oe-init-build-env build
#   bitbake core-image-base
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# All layers are cloned into the bind-mounted /workspace volume so that they
# persist on the host between container invocations.
WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"
CONF_DIR="${BUILD_DIR}/conf"
METALAYER_DIR="${BUILD_DIR}/meta-layers"

# Yocto Scarthgap branch name — must be identical across all layers.
BRANCH="scarthgap"

# Location of the config templates baked into the image.
CONF_SRC="/opt/yocto/conf"

# ─── Helper: clone only if the directory does not already exist ───────────────
clone_if_missing() {
    local url="$1"
    local dest="$2"
    local branch="$3"

    pushd "$METALAYER_DIR" &> /dev/null
    if [ -d "${dest}/.git" ]; then
        echo "  ✓  $(basename "${dest}") already present — skipping"
    else
        echo "  →  Cloning $(basename "${dest}") (branch: ${branch}) …"
        # --depth 1 fetches only the tip of the branch, saving ~1–2 GB of history.
        # Remove --depth 1 if you need full git history or plan to contribute upstream.
        git clone --branch "${branch}" --depth 1 "${url}" "${dest}"
    fi
    popd &> /dev/null
}

# ─── Clone layers ─────────────────────────────────────────────────────────────
echo ""
echo "═══ Cloning Yocto layers (Scarthgap) ════════════════════════════"
echo ""

mkdir -p "${METALAYER_DIR}"
cd "${WORKSPACE}"

# Poky: the Yocto reference distribution; includes BitBake and OE-Core.
clone_if_missing \
    "https://git.yoctoproject.org/poky" \
    "poky" \
    "${BRANCH}"

# meta-openembedded: provides meta-oe, meta-python, meta-networking.
# meta-networking is required for many networking packages (dhcpcd, etc.).
clone_if_missing \
    "https://git.openembedded.org/meta-openembedded" \
    "meta-openembedded" \
    "${BRANCH}"

# meta-raspberrypi: BSP layer for all Raspberry Pi boards including the CM4.
# Machine name used: raspberrypi-cm4
clone_if_missing \
    "https://git.yoctoproject.org/meta-raspberrypi" \
    "meta-raspberrypi" \
    "${BRANCH}"

# ─── Create build directory structure ────────────────────────────────────────
echo ""
echo "═══ Initialising build directory ════════════════════════════════"
echo ""

# Create the conf directory that Yocto expects before oe-init-build-env.
# When oe-init-build-env is sourced later it will see existing conf files
# and will NOT overwrite them with defaults.
mkdir -p "${CONF_DIR}"

# ─── Install configuration files ─────────────────────────────────────────────
echo "  →  Installing local.conf …"
cp "${CONF_SRC}/local.conf" "${CONF_DIR}/local.conf"

echo "  →  Installing bblayers.conf …"
cp "${CONF_SRC}/bblayers.conf" "${CONF_DIR}/bblayers.conf"

# ─── Enter build shell ────────────────────────────────────────────────────────

source poky/oe-init-build-env build
bash

#echo ""
#echo "═══ Setup complete ══════════════════════════════════════════════"
#echo ""
#echo "Next steps:"
#echo ""
#echo "  1. Enter the container:"
#echo "       docker compose run --rm -it yocto-builder"
#echo ""
#echo "  2. Initialise the build environment (sets PATH for BitBake):"
#echo "       source poky/oe-init-build-env build"
#echo ""
#echo "  3. Start the build (~1–3 hours on first run):"
#echo "       bitbake core-image-base"
#echo ""
#echo "  Output image will be at:"
#echo "    workspace/build/tmp/deploy/images/raspberrypi-cm4/"
#echo ""
