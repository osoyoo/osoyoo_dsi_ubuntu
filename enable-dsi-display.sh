#!/bin/bash
# Script to manually enable the DSI display
# Run this if the DSI screen is detected but not showing anything

echo "=========================================="
echo "OSOYOO DSI Display Manual Enable"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Find the DSI connector
DSI_CONNECTOR=$(ls /sys/class/drm/card*-DSI-* 2>/dev/null | head -1)

if [ -z "$DSI_CONNECTOR" ]; then
    echo "ERROR: No DSI connector found!"
    echo "Make sure the driver is installed and loaded."
    exit 1
fi

DSI_NAME=$(basename "$DSI_CONNECTOR")
echo "Found DSI connector: $DSI_NAME"
echo ""

# Check current status
echo "Current status:"
echo "  Connected: $(cat $DSI_CONNECTOR/status)"
echo "  Enabled: $(cat $DSI_CONNECTOR/enabled)"
echo "  DPMS: $(cat $DSI_CONNECTOR/dpms)"
echo "  Modes: $(cat $DSI_CONNECTOR/modes)"
echo ""

# Try to enable the display using DRM
echo "Attempting to enable DSI display..."
echo ""

# Method 1: Using modetest (if available)
if command -v modetest >/dev/null 2>&1; then
    echo "Using modetest to configure display..."

    # Get connector ID
    CONN_ID=$(modetest -M vc4 | grep "$DSI_NAME" | grep -oP 'id:\K[0-9]+' | head -1)
    # Get CRTC ID
    CRTC_ID=$(modetest -M vc4 | grep 'crtc' | head -1 | grep -oP 'id:\K[0-9]+')
    # Get mode
    MODE=$(cat $DSI_CONNECTOR/modes | head -1)

    if [ -n "$CONN_ID" ] && [ -n "$CRTC_ID" ] && [ -n "$MODE" ]; then
        echo "  Connector ID: $CONN_ID"
        echo "  CRTC ID: $CRTC_ID"
        echo "  Mode: $MODE"
        modetest -M vc4 -s ${CONN_ID}@${CRTC_ID}:${MODE}
        echo "  Display configured with modetest"
    else
        echo "  Could not get display parameters"
    fi
else
    echo "modetest not available (install with: apt-get install libdrm-tests)"
fi

echo ""

# Method 2: Enable via sysfs DPMS
echo "Setting DPMS to On..."
echo "On" > $DSI_CONNECTOR/dpms 2>/dev/null || echo "  Could not set DPMS (this is normal)"

echo ""
echo "=========================================="
echo "Display Enable Attempted"
echo "=========================================="
echo ""
echo "New status:"
echo "  Connected: $(cat $DSI_CONNECTOR/status)"
echo "  Enabled: $(cat $DSI_CONNECTOR/enabled)"
echo "  DPMS: $(cat $DSI_CONNECTOR/dpms)"
echo ""

if [ "$(cat $DSI_CONNECTOR/enabled)" = "enabled" ]; then
    echo "✓ SUCCESS! DSI display is now enabled."
    echo ""
    echo "If the screen is still black, try:"
    echo "1. Disconnect HDMI cables"
    echo "2. Reboot the system"
    echo "3. Check backlight power cable connection"
else
    echo "⚠ Display is still not enabled."
    echo ""
    echo "This usually means:"
    echo "1. The display manager (GDM/Wayland) is not configured to use it"
    echo "2. HDMI is taking priority"
    echo "3. A reboot is needed after driver installation"
    echo ""
    echo "Try these steps:"
    echo "1. Disconnect all HDMI cables"
    echo "2. sudo reboot"
    echo "3. Check if config.txt has: display_auto_detect=0"
fi
echo ""
