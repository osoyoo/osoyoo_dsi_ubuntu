#!/bin/bash
# Script to diagnose DKMS build errors
# Run this on your Raspberry Pi to see what went wrong

echo "=========================================="
echo "OSOYOO DSI Driver - Build Error Diagnosis"
echo "=========================================="
echo ""

# Check if build log exists
if [ -f /var/lib/dkms/osoyoo-dsi-panel/1.0/build/make.log ]; then
    echo "DKMS Build Log:"
    echo "----------------------------------------"
    cat /var/lib/dkms/osoyoo-dsi-panel/1.0/build/make.log
    echo "----------------------------------------"
    echo ""
else
    echo "ERROR: Build log not found at /var/lib/dkms/osoyoo-dsi-panel/1.0/build/make.log"
    echo ""
fi

# Check kernel version
echo "System Information:"
echo "  Kernel: $(uname -r)"
echo "  OS: $(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')"
echo ""

# Check if kernel headers are installed
KERNEL_VER=$(uname -r)
echo "Kernel Headers Check:"
if [ -d "/lib/modules/${KERNEL_VER}/build" ]; then
    echo "  ✓ Kernel headers are installed at /lib/modules/${KERNEL_VER}/build"
else
    echo "  ✗ Kernel headers NOT found at /lib/modules/${KERNEL_VER}/build"
    echo "  Install with: sudo apt-get install linux-headers-${KERNEL_VER}"
fi
echo ""

# Check if source files exist
echo "Driver Source Files:"
if [ -d /var/lib/dkms/osoyoo-dsi-panel/1.0 ]; then
    echo "  Source directory: /var/lib/dkms/osoyoo-dsi-panel/1.0"
    ls -la /var/lib/dkms/osoyoo-dsi-panel/1.0/build/*.c 2>/dev/null || echo "  No .c files found"
else
    echo "  ✗ Source directory not found"
fi
echo ""

# Check for common compilation issues
if [ -f /var/lib/dkms/osoyoo-dsi-panel/1.0/build/osoyoo-panel-regulator.c ]; then
    echo "Checking osoyoo-panel-regulator.c for common issues:"

    if grep -q "#include <linux/i2c.h>" /var/lib/dkms/osoyoo-dsi-panel/1.0/build/osoyoo-panel-regulator.c; then
        echo "  ✓ I2C header included"
    else
        echo "  ✗ I2C header MISSING"
    fi

    if grep -q "FB_BLANK_UNBLANK" /var/lib/dkms/osoyoo-dsi-panel/1.0/build/osoyoo-panel-regulator.c; then
        echo "  ⚠ Using FB_BLANK_UNBLANK (may fail on kernel 7.0+)"
    else
        echo "  ✓ Not using FB_BLANK_UNBLANK"
    fi

    if grep -q "static int osoyoo_panel_gpio_set" /var/lib/dkms/osoyoo-dsi-panel/1.0/build/osoyoo-panel-regulator.c; then
        echo "  ✓ GPIO set returns int (kernel 6.17+ compatible)"
    elif grep -q "static void osoyoo_panel_gpio_set" /var/lib/dkms/osoyoo-dsi-panel/1.0/build/osoyoo-panel-regulator.c; then
        echo "  ✓ GPIO set returns void (kernel <6.17 compatible)"
    fi
fi
echo ""

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Review the build log above to identify the error"
echo "2. If kernel headers are missing, install them"
echo "3. If there are API compatibility issues, run cleanup and reinstall:"
echo "   cd ~/osoyoo_dsi_ubuntu"
echo "   sudo bash cleanup-and-install.sh"
echo "   sudo ./install-direct.sh"
echo ""
