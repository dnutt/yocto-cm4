#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Container entrypoint
#
# Prints a short usage reminder, then hands control to whatever CMD the user
# passed (defaulting to /bin/bash for an interactive session).
# ─────────────────────────────────────────────────────────────────────────────
set -e

echo "┌─────────────────────────────────────────────────────┐"
echo "│  Yocto Scarthgap 5.0 LTS  ·  Raspberry Pi CM4       │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

if [ -d /workspace/poky ]; then
    echo "Workspace ready. To build:"
    echo "  source poky/oe-init-build-env build"
    echo "  bitbake core-image-base"
else
    echo "Workspace not initialised. Run the setup script first:"
    echo "  docker compose run --rm yocto-builder /opt/yocto/scripts/setup.sh"
fi

echo ""

# Execute the CMD (or any arguments passed to docker run / compose run).
exec "$@"
