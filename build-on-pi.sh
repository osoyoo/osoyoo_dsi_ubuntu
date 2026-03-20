#!/bin/bash
# Build script to be run ON Raspberry Pi (not macOS)
# This creates a proper .deb package using dpkg-buildpackage

set -e

echo "=========================================="
echo "Building OSOYOO DSI Panel DKMS Package"
echo "ON Raspberry Pi (Linux)"
echo "=========================================="
echo ""

# Check if we're on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "ERROR: This script must be run on a Raspberry Pi or Linux system."
    echo "       Current OS: $OSTYPE"
    exit 1
fi

# Check if required tools are installed
echo "Checking required tools..."
MISSING=""

if ! command -v dpkg-buildpackage &> /dev/null; then
    MISSING="$MISSING dpkg-dev"
fi

if ! command -v debhelper &> /dev/null; then
    MISSING="$MISSING debhelper"
fi

if ! command -v dkms &> /dev/null; then
    MISSING="$MISSING dkms"
fi

if [ ! -z "$MISSING" ]; then
    echo ""
    echo "Missing required packages:$MISSING"
    echo ""
    echo "Installing required packages..."
    sudo apt-get update
    sudo apt-get install -y build-essential debhelper dh-dkms dkms device-tree-compiler
fi

echo "✓ All required tools installed"
echo ""

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf debian/osoyoo-dsi-panel-dkms
rm -f ../*.deb ../*.changes ../*.buildinfo ../*.dsc ../*.tar.* 2>/dev/null || true
make clean 2>/dev/null || true

echo "✓ Cleaned"
echo ""

# Build the package
echo "Building package..."
dpkg-buildpackage -us -uc -b

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Package created:"
ls -lh ../*.deb

echo ""
echo "To install locally:"
echo "  sudo dpkg -i ../osoyoo-dsi-panel-dkms_*.deb"
echo ""
echo "To upload to GitHub:"
echo "  gh release upload v1.0 ../osoyoo-dsi-panel-dkms_*.deb --clobber"
echo ""
