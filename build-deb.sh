#!/bin/bash
# Build script for OSOYOO DSI Panel DKMS package

set -e

echo "Building OSOYOO DSI Panel DKMS package..."

# Check if required tools are installed
if ! command -v dpkg-buildpackage &> /dev/null; then
    echo "Error: dpkg-buildpackage not found. Please install build tools:"
    echo "  sudo apt-get install build-essential debhelper dkms"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf debian/osoyoo-dsi-panel-dkms
rm -f ../*.deb ../*.changes ../*.buildinfo ../*.dsc ../*.tar.* 2>/dev/null || true

# Build the package
echo "Building package..."
dpkg-buildpackage -us -uc -b

echo ""
echo "Build complete!"
echo "Package created: ../osoyoo-dsi-panel-dkms_1.0-1_all.deb"
echo ""
echo "To install locally:"
echo "  sudo dpkg -i ../osoyoo-dsi-panel-dkms_1.0-1_all.deb"
echo "  sudo apt-get install -f  # Install dependencies if needed"
echo ""
echo "To distribute via repository, you'll need to sign and upload the package."
