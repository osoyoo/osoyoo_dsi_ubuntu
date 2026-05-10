#!/bin/bash
# Force bind the OSOYOO DSI driver to the panel device
# Run this if the panel is detected but driver isn't binding

echo "=========================================="
echo "OSOYOO DSI Driver Force Bind"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Find the DSI device
DSI_DEVICE=$(ls /sys/bus/mipi-dsi/devices/ | grep 'dsi\.[0-9]$' | head -1)

if [ -z "$DSI_DEVICE" ]; then
    echo "ERROR: No MIPI DSI device found!"
    echo "Make sure the device tree overlay is loaded."
    exit 1
fi

echo "Found MIPI DSI device: $DSI_DEVICE"

# Check if driver is already bound
if [ -L "/sys/bus/mipi-dsi/devices/$DSI_DEVICE/driver" ]; then
    CURRENT_DRIVER=$(readlink /sys/bus/mipi-dsi/devices/$DSI_DEVICE/driver | xargs basename)
    echo "Driver already bound: $CURRENT_DRIVER"
    echo ""

    # Check if it's creating a DRM device
    if ls /sys/class/drm/card*-DSI-* >/dev/null 2>&1; then
        echo "✓ DRM DSI device exists"
        ls /sys/class/drm/card*-DSI-*
    else
        echo "⚠ Driver is bound but no DRM device created"
        echo "This might indicate a driver initialization problem."
        echo ""
        echo "Try reloading the driver:"
        echo "  sudo rmmod osoyoo_panel_dsi"
        echo "  sudo modprobe osoyoo_panel_dsi"
    fi
    exit 0
fi

echo "Driver not bound. Attempting to bind osoyoo-dsi driver..."
echo ""

# Try to bind the driver
echo "$DSI_DEVICE" > /sys/bus/mipi-dsi/drivers/osoyoo-dsi/bind 2>&1

sleep 1

# Check if binding succeeded
if [ -L "/sys/bus/mipi-dsi/devices/$DSI_DEVICE/driver" ]; then
    echo "✓ SUCCESS! Driver bound successfully"
    CURRENT_DRIVER=$(readlink /sys/bus/mipi-dsi/devices/$DSI_DEVICE/driver | xargs basename)
    echo "  Driver: $CURRENT_DRIVER"
    echo ""

    # Check for DRM device
    sleep 1
    if ls /sys/class/drm/card*-DSI-* >/dev/null 2>&1; then
        echo "✓ DRM DSI device created:"
        for dsi in /sys/class/drm/card*-DSI-*; do
            DSI_NAME=$(basename $dsi)
            echo "  $DSI_NAME: $(cat $dsi/status) - $(cat $dsi/enabled)"
        done
    else
        echo "⚠ Driver bound but no DRM device appeared"
        echo "Check kernel logs: sudo dmesg | tail -20"
    fi
else
    echo "✗ FAILED to bind driver"
    echo ""
    echo "Possible reasons:"
    echo "1. Driver initialization error - check: sudo dmesg | grep osoyoo"
    echo "2. Device tree configuration issue"
    echo "3. Hardware connection problem"
    echo ""
    echo "Try reloading modules:"
    echo "  sudo rmmod osoyoo_panel_dsi osoyoo_panel_regulator"
    echo "  sudo modprobe osoyoo_panel_regulator"
    echo "  sudo modprobe osoyoo_panel_dsi"
fi

echo ""
