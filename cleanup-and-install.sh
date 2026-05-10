#!/bin/bash
# Cleanup script for broken DKMS installation and reinstall
# This fixes the dpkg error state caused by failed DKMS builds

set -e

echo "=========================================="
echo "OSOYOO DSI Driver - Cleanup and Reinstall"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "Step 1: Removing old DKMS module..."
dkms remove osoyoo-dsi-panel/1.0 --all 2>&1 || true
rm -rf /usr/src/osoyoo-dsi-panel-1.0 2>/dev/null || true
rm -rf /var/lib/dkms/osoyoo-dsi-panel 2>/dev/null || true
echo "✓ Old DKMS module removed"
echo ""

echo "Step 2: Fixing dpkg package state..."
# Complete the linux-headers installation that was interrupted
dpkg --configure -a
echo "✓ Package state fixed"
echo ""

echo "Step 3: Verifying kernel headers are installed..."
KERNEL_VER=$(uname -r)
if dpkg -l | grep -q "linux-headers-${KERNEL_VER}"; then
    echo "✓ Kernel headers for $KERNEL_VER are installed"
else
    echo "Installing kernel headers for $KERNEL_VER..."
    apt-get install -y linux-headers-${KERNEL_VER}
fi
echo ""

echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "Now run the installer:"
echo "  sudo ./install-direct.sh"
echo ""
