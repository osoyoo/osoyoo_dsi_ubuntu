#!/bin/bash
# Test script to verify OS and kernel detection without installing
# Run this to see what the installer will detect on your system

set -e

echo "=========================================="
echo "OSOYOO DSI Driver - System Detection Test"
echo "=========================================="
echo ""

# Hardware detection function (same as in install-direct.sh)
detect_hardware() {
    local pi_model="unknown"
    local os_distro="unknown"
    local os_version="unknown"
    local kernel_version=$(uname -r)
    local arch=$(uname -m)

    # Detect Raspberry Pi Model
    if [ -f /proc/device-tree/model ]; then
        local device_model=$(cat /proc/device-tree/model | tr -d '\0')

        case "$device_model" in
            *"Raspberry Pi 5"*|*"Raspberry Pi Compute Module 5"*)
                pi_model="pi5"
                ;;
            *"Raspberry Pi 4"*|*"Raspberry Pi Compute Module 4"*)
                pi_model="pi4"
                ;;
            *"Raspberry Pi 3"*|*"Raspberry Pi Compute Module 3"*)
                pi_model="pi3"
                ;;
            *)
                # Fallback to /proc/cpuinfo
                if grep -q "BCM2712" /proc/cpuinfo 2>/dev/null; then
                    pi_model="pi5"
                elif grep -q "BCM2711" /proc/cpuinfo 2>/dev/null; then
                    pi_model="pi4"
                elif grep -q "BCM2837" /proc/cpuinfo 2>/dev/null; then
                    pi_model="pi3"
                fi
                ;;
        esac
    fi

    # Detect OS Distribution and Version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            raspbian|debian) os_distro="debian" ;;
            ubuntu) os_distro="ubuntu" ;;
            *) os_distro="$ID" ;;
        esac
        os_version="$VERSION_ID"
    fi

    echo "$pi_model|$os_distro|$os_version|$kernel_version|$arch"
}

# Kernel version comparison function
kernel_version_gte() {
    local current_kernel="$1"
    local target_major="$2"
    local target_minor="${3:-0}"

    # Extract major and minor version from kernel string
    local kernel_major=$(echo "$current_kernel" | cut -d'.' -f1)
    local kernel_minor=$(echo "$current_kernel" | cut -d'.' -f2 | sed 's/[^0-9].*//')

    # Compare versions
    if [ "$kernel_major" -gt "$target_major" ]; then
        return 0
    elif [ "$kernel_major" -eq "$target_major" ] && [ "$kernel_minor" -ge "$target_minor" ]; then
        return 0
    else
        return 1
    fi
}

# Run detection
HARDWARE_INFO=$(detect_hardware)
PI_MODEL=$(echo "$HARDWARE_INFO" | cut -d'|' -f1)
OS_DISTRO=$(echo "$HARDWARE_INFO" | cut -d'|' -f2)
OS_VERSION=$(echo "$HARDWARE_INFO" | cut -d'|' -f3)
KERNEL_VERSION=$(echo "$HARDWARE_INFO" | cut -d'|' -f4)
ARCH=$(echo "$HARDWARE_INFO" | cut -d'|' -f5)

echo "Detected System Configuration:"
echo "  Raspberry Pi Model: $PI_MODEL"
echo "  OS Distribution: $OS_DISTRO $OS_VERSION"
echo "  Kernel Version: $KERNEL_VERSION"
echo "  Architecture: $ARCH"
echo ""

# Determine GPIO API requirement
if kernel_version_gte "$KERNEL_VERSION" 6 17; then
    echo "GPIO API Compatibility:"
    echo "  Required API: New (kernel >= 6.17)"
    echo "  Return type: int"
    echo "  ✓ Driver will be patched for kernel 6.17+ GPIO API"
else
    echo "GPIO API Compatibility:"
    echo "  Required API: Old (kernel < 6.17)"
    echo "  Return type: void"
    echo "  ✓ Driver will be patched for kernel <6.17 GPIO API"
fi
echo ""

# Check if this is a supported configuration
if [ "$PI_MODEL" = "unknown" ]; then
    echo "⚠ WARNING: Could not detect Raspberry Pi model"
    echo "  This driver is designed for Raspberry Pi 3, 4, 5, and CM modules"
elif [ "$OS_DISTRO" != "ubuntu" ]; then
    echo "⚠ WARNING: This installer is optimized for Ubuntu"
    echo "  Detected: $OS_DISTRO"
    echo "  For Raspberry Pi OS, use: https://github.com/osoyoo/osoyoo-dsi-panel"
else
    echo "✓ System is compatible with this driver"

    # Ubuntu version specific notes
    if [ "$OS_DISTRO" = "ubuntu" ]; then
        UBUNTU_VER_MAJOR=$(echo "$OS_VERSION" | cut -d'.' -f1)
        if [ -n "$UBUNTU_VER_MAJOR" ]; then
            if [ "$UBUNTU_VER_MAJOR" -ge 26 ]; then
                echo "  ✓ Ubuntu 26.04+ detected - Full auto-detection support"
            elif [ "$UBUNTU_VER_MAJOR" -ge 24 ]; then
                echo "  ✓ Ubuntu 24.04/25.10 - Full auto-detection support"
            else
                echo "  ⚠ Ubuntu < 24.04 - May work but not fully tested"
            fi
        fi
    fi
fi
echo ""

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "If everything looks correct, run the installer:"
echo "  sudo ./install-direct.sh"
echo ""
echo "The installer will:"
echo "  1. Install dependencies"
echo "  2. Automatically patch driver for kernel $KERNEL_VERSION"
echo "  3. Build and install the driver"
echo "  4. Configure overlay paths for Ubuntu"
echo ""
