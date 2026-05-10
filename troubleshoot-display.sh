#!/bin/bash
# Troubleshooting script for DSI display issues
# Run this to diagnose why the screen isn't displaying

echo "=========================================="
echo "OSOYOO DSI Display Troubleshooting"
echo "=========================================="
echo ""

# Check if running as root
NEEDS_SUDO=""
if [ "$EUID" -ne 0 ]; then
    echo "Note: Some checks require sudo. Rerun with 'sudo' for full diagnostics."
    NEEDS_SUDO="sudo "
    echo ""
fi

# 1. Check if driver modules are loaded
echo "1. Driver Module Status:"
echo "----------------------------------------"
if lsmod | grep -q osoyoo_panel_dsi; then
    echo "✓ osoyoo_panel_dsi module is loaded"
    lsmod | grep osoyoo
else
    echo "✗ osoyoo_panel_dsi module NOT loaded"
fi
echo ""

# 2. Check config.txt settings
echo "2. Config.txt Settings:"
echo "----------------------------------------"
if [ -f /boot/firmware/config.txt ]; then
    echo "Checking /boot/firmware/config.txt:"

    if grep -q "display_auto_detect=0" /boot/firmware/config.txt; then
        echo "  ✓ display_auto_detect=0"
    else
        echo "  ✗ display_auto_detect=0 NOT found (should be set to 0)"
    fi

    if grep -q "dtparam=i2c_arm_baudrate" /boot/firmware/config.txt; then
        echo "  ✓ i2c_arm_baudrate is set"
        grep "i2c_arm_baudrate" /boot/firmware/config.txt | head -1
    else
        echo "  ✗ i2c_arm_baudrate NOT set (should be 100000)"
    fi

    if grep -q "dtoverlay=osoyoo-panel-dsi" /boot/firmware/config.txt; then
        echo "  ✓ OSOYOO overlay configured:"
        grep "dtoverlay=osoyoo" /boot/firmware/config.txt
    else
        echo "  ✗ OSOYOO overlay NOT configured"
    fi
else
    echo "✗ /boot/firmware/config.txt not found"
fi
echo ""

# 3. Check if overlays are installed
echo "3. Device Tree Overlay Files:"
echo "----------------------------------------"
if [ -f /boot/firmware/current/overlays/osoyoo-panel-dsi-10inch.dtbo ]; then
    echo "✓ /boot/firmware/current/overlays/osoyoo-panel-dsi-10inch.dtbo exists"
else
    echo "✗ /boot/firmware/current/overlays/osoyoo-panel-dsi-10inch.dtbo NOT found"
fi

if [ -f /boot/firmware/current/overlays/osoyoo-panel-dsi-7inch.dtbo ]; then
    echo "✓ /boot/firmware/current/overlays/osoyoo-panel-dsi-7inch.dtbo exists"
else
    echo "✗ /boot/firmware/current/overlays/osoyoo-panel-dsi-7inch.dtbo NOT found"
fi
echo ""

# 4. Check kernel messages (requires sudo)
echo "4. Kernel Messages:"
echo "----------------------------------------"
${NEEDS_SUDO}dmesg | grep -i "osoyoo\|dsi" | tail -30
echo ""

# 5. Check I2C devices
echo "5. I2C Device Detection:"
echo "----------------------------------------"
if command -v i2cdetect >/dev/null 2>&1; then
    echo "Scanning I2C bus 1:"
    ${NEEDS_SUDO}i2cdetect -y 1 2>/dev/null || echo "Run with sudo to scan I2C bus"
else
    echo "i2c-tools not installed. Install with: sudo apt-get install i2c-tools"
fi
echo ""

# 6. Check display output
echo "6. Display/Framebuffer Status:"
echo "----------------------------------------"
if [ -d /sys/class/drm ]; then
    echo "DRM displays:"
    ls -1 /sys/class/drm/card*/status 2>/dev/null | while read status_file; do
        status=$(cat "$status_file" 2>/dev/null)
        echo "  $(dirname $status_file | xargs basename): $status"
    done
else
    echo "✗ No DRM displays found"
fi
echo ""

# 7. DSI port detection
echo "7. DSI Port Configuration:"
echo "----------------------------------------"
if [ -d /sys/class/drm ]; then
    for dsi in /sys/class/drm/card*-DSI-*; do
        if [ -d "$dsi" ]; then
            echo "  Found: $(basename $dsi)"
            if [ -f "$dsi/status" ]; then
                echo "    Status: $(cat $dsi/status)"
            fi
            if [ -f "$dsi/enabled" ]; then
                echo "    Enabled: $(cat $dsi/enabled)"
            fi
        fi
    done
else
    echo "No DSI ports found in /sys/class/drm"
fi
echo ""

echo "=========================================="
echo "Common Issues and Solutions:"
echo "=========================================="
echo ""
echo "1. If modules are loaded but screen is black:"
echo "   - Check physical DSI cable connection"
echo "   - Try: dsi0,4lane instead of dsi1,4lane (or vice versa)"
echo "   - Check if power cable is connected to the screen"
echo ""
echo "2. If 'display_auto_detect=0' is missing:"
echo "   sudo nano /boot/firmware/config.txt"
echo "   Set: display_auto_detect=0"
echo "   Then: sudo reboot"
echo ""
echo "3. If I2C errors in kernel messages:"
echo "   Try slower I2C speed in config.txt:"
echo "   dtparam=i2c_arm_baudrate=50000"
echo ""
echo "4. Check which DSI port your screen is connected to:"
echo "   - Pi 5 has DSI-0 port (try: dsi0,4lane)"
echo "   - CM5 often uses DSI-1 port (try: dsi1,4lane)"
echo ""
echo "5. If using 7-inch panel instead of 10.1-inch:"
echo "   Change overlay to: dtoverlay=osoyoo-panel-dsi-7inch"
echo ""
