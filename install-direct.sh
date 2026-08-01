#!/bin/bash
# Direct installation script (no .deb package needed)
# This script installs the driver directly using DKMS
# Run this ON your Raspberry Pi

set -e

PACKAGE_NAME="osoyoo-dsi-panel"
PACKAGE_VERSION="1.0"
SRC_BASE="/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}"

echo "=========================================="
echo "OSOYOO DSI Panel Driver Installation"
echo "Direct Install (No .deb package)"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Optional panel argument. Used only to print the matching config.txt line at the end;
# the driver and both overlays are installed either way.
#   sudo ./install-direct.sh 7inch    -> 7" (720x1280) panel
#   sudo ./install-direct.sh 10inch   -> 10.1" (800x1280) panel
PANEL_ARG="${1:-}"
case "$PANEL_ARG" in
    7|7in|7inch|7-inch)                   PANEL_SIZE="7inch" ;;
    10|10in|10inch|10-inch|10.1|10.1inch) PANEL_SIZE="10inch" ;;
    "")                                   PANEL_SIZE="" ;;
    *) echo "Note: unknown panel '$PANEL_ARG' (expected 7inch or 10inch); continuing anyway."
       PANEL_SIZE="" ;;
esac

# Hardware detection function
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
# Returns: 0 if kernel >= target version, 1 otherwise
kernel_version_gte() {
    local current_kernel="$1"
    local target_major="$2"
    local target_minor="${3:-0}"

    # Extract major and minor version from kernel string (e.g., "6.17.0-rpi8" -> 6, 17)
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

# Automatic driver code patching based on kernel version
patch_driver_for_kernel() {
    local src_file="$1"
    local kernel_ver="$2"
    local needs_new_api=false

    # Check if kernel >= 6.17 (new GPIO API required)
    if kernel_version_gte "$kernel_ver" 6 17; then
        needs_new_api=true
    fi

    # Check current API in the file
    local current_api_is_new=false
    if grep -q "^static int osoyoo_panel_gpio_set" "$src_file" 2>/dev/null; then
        current_api_is_new=true
    fi

    # Patch if mismatch
    if [ "$needs_new_api" = true ] && [ "$current_api_is_new" = false ]; then
        echo "  -> Patching $src_file for kernel 6.17+ (new GPIO API: int return)"
        # Change void to int and add return 0
        sed -i 's/^static void osoyoo_panel_gpio_set/static int osoyoo_panel_gpio_set/' "$src_file"
        # Make sure there's a return statement before the closing brace
        if ! grep -q "return 0;" "$src_file"; then
            # Add return 0; before the last closing brace in the function
            sed -i '/^static int osoyoo_panel_gpio_set/,/^}/ {
                /^}/ {
                    i\
\	return 0;
                }
            }' "$src_file"
        fi
    elif [ "$needs_new_api" = false ] && [ "$current_api_is_new" = true ]; then
        echo "  -> Patching $src_file for kernel <6.17 (old GPIO API: void return)"
        # Change int to void and remove return statement ONLY in osoyoo_panel_gpio_set function
        sed -i 's/^static int osoyoo_panel_gpio_set/static void osoyoo_panel_gpio_set/' "$src_file"
        # Remove return 0; only within osoyoo_panel_gpio_set function (between function start and its closing brace)
        sed -i '/^static void osoyoo_panel_gpio_set/,/^}/ { /^\s*return 0;$/d; }' "$src_file"
    fi
}

# Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y dkms device-tree-compiler

# Install kernel headers based on distribution
KERNEL_VERSION=$(uname -r)
if apt-cache search raspberrypi-kernel-headers | grep -q raspberrypi-kernel-headers; then
    # Raspberry Pi OS
    echo "Detected Raspberry Pi OS - installing raspberrypi-kernel-headers..."
    apt-get install -y raspberrypi-kernel-headers
elif apt-cache search linux-headers-${KERNEL_VERSION} | grep -q linux-headers-${KERNEL_VERSION}; then
    # Standard Debian/Ubuntu
    echo "Detected Debian/Ubuntu - installing linux-headers-${KERNEL_VERSION}..."
    apt-get install -y linux-headers-${KERNEL_VERSION}
else
    echo "WARNING: Could not find kernel headers package."
    echo "         Attempting to install generic linux-headers..."
    apt-get install -y linux-headers-$(uname -r) || apt-get install -y linux-headers-generic || true
fi

echo "✓ Dependencies installed"
echo ""

# Detect hardware
echo "Detecting hardware and OS..."
HARDWARE_INFO=$(detect_hardware)
PI_MODEL=$(echo "$HARDWARE_INFO" | cut -d'|' -f1)
OS_DISTRO=$(echo "$HARDWARE_INFO" | cut -d'|' -f2)
OS_VERSION=$(echo "$HARDWARE_INFO" | cut -d'|' -f3)
KERNEL_VERSION=$(echo "$HARDWARE_INFO" | cut -d'|' -f4)
ARCH=$(echo "$HARDWARE_INFO" | cut -d'|' -f5)

echo "  Raspberry Pi Model: $PI_MODEL"
echo "  OS Distribution: $OS_DISTRO $OS_VERSION"
echo "  Kernel Version: $KERNEL_VERSION"
echo "  Architecture: $ARCH"

# Determine GPIO API requirement
if kernel_version_gte "$KERNEL_VERSION" 6 17; then
    echo "  GPIO API: New (kernel >= 6.17, int return type)"
    GPIO_API="new"
else
    echo "  GPIO API: Old (kernel < 6.17, void return type)"
    GPIO_API="old"
fi
echo ""

# Check if model-specific sources exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/src/${PI_MODEL}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "WARNING: No specific driver for $PI_MODEL found."
    echo "         Checking for fallback drivers..."

    # Fallback logic
    if [ -d "${SCRIPT_DIR}/src/pi4" ]; then
        echo "         Using Pi 4 driver as fallback."
        SOURCE_DIR="${SCRIPT_DIR}/src/pi4"
    elif [ -d "${SCRIPT_DIR}/src/pi3" ]; then
        echo "         Using Pi 3 driver as fallback."
        SOURCE_DIR="${SCRIPT_DIR}/src/pi3"
    else
        echo "ERROR: No compatible driver found."
        exit 1
    fi
else
    echo "Using model-specific driver: $SOURCE_DIR"
fi
echo ""

# Remove old installation if exists
if dkms status -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION} 2>/dev/null | grep -q "installed"; then
    echo "Removing previous installation..."
    dkms remove -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION} --all || true
fi

# Create source directory
echo "Creating source directory..."
rm -rf "${SRC_BASE}"
mkdir -p "${SRC_BASE}"

# Copy files
echo "Copying source files..."
cp "${SCRIPT_DIR}/Makefile" "${SRC_BASE}/"
cp "${SCRIPT_DIR}/dkms.conf" "${SRC_BASE}/"
cp "$SOURCE_DIR/osoyoo-panel-dsi.c" "${SRC_BASE}/"
cp "$SOURCE_DIR/osoyoo-panel-regulator.c" "${SRC_BASE}/"
cp "$SOURCE_DIR/osoyoo-panel-dsi-7inch.dts" "${SRC_BASE}/"
cp "$SOURCE_DIR/osoyoo-panel-dsi-10inch.dts" "${SRC_BASE}/"

echo "✓ Files copied"
echo ""

# The driver source is version-guarded (LINUX_VERSION_CODE >= KERNEL_VERSION(6,17,0)),
# so it compiles correctly on both the old (void) and new (int) GPIO set-callback API
# with no source patching needed.

# Add to DKMS
echo "Adding module to DKMS..."
dkms add -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION}

# Build
echo "Building driver for kernel $KERNEL_VERSION..."
if dkms build -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION}; then
    echo "✓ Build successful!"
else
    echo "ERROR: Build failed."
    echo "Make sure kernel headers are installed:"
    echo "  sudo apt-get install raspberrypi-kernel-headers"
    exit 1
fi
echo ""

# Install
echo "Installing driver module..."
if dkms install -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION}; then
    echo "✓ Installation successful!"
else
    echo "ERROR: Installation failed."
    exit 1
fi
echo ""

# Install device tree overlays
echo "Installing device tree overlays..."
if [ -f "${SRC_BASE}/osoyoo-panel-dsi-7inch.dts" ]; then
    dtc -I dts -O dtb -o /tmp/osoyoo-panel-dsi-7inch.dtbo \
        "${SRC_BASE}/osoyoo-panel-dsi-7inch.dts" 2>/dev/null

    mkdir -p /boot/overlays /boot/firmware/overlays 2>/dev/null || true
    cp /tmp/osoyoo-panel-dsi-7inch.dtbo /boot/overlays/ 2>/dev/null || true
    cp /tmp/osoyoo-panel-dsi-7inch.dtbo /boot/firmware/overlays/ 2>/dev/null || true

    # Ubuntu uses os_prefix=current/ so also copy to current/overlays
    if [ -d /boot/firmware/current ]; then
        mkdir -p /boot/firmware/current/overlays 2>/dev/null || true
        cp /tmp/osoyoo-panel-dsi-7inch.dtbo /boot/firmware/current/overlays/ 2>/dev/null || true
        echo "  ✓ 7-inch panel overlay installed (including Ubuntu current/ path)"
    else
        echo "  ✓ 7-inch panel overlay installed"
    fi
    rm /tmp/osoyoo-panel-dsi-7inch.dtbo
fi

if [ -f "${SRC_BASE}/osoyoo-panel-dsi-10inch.dts" ]; then
    dtc -I dts -O dtb -o /tmp/osoyoo-panel-dsi-10inch.dtbo \
        "${SRC_BASE}/osoyoo-panel-dsi-10inch.dts" 2>/dev/null

    mkdir -p /boot/overlays /boot/firmware/overlays 2>/dev/null || true
    cp /tmp/osoyoo-panel-dsi-10inch.dtbo /boot/overlays/ 2>/dev/null || true
    cp /tmp/osoyoo-panel-dsi-10inch.dtbo /boot/firmware/overlays/ 2>/dev/null || true

    # Ubuntu uses os_prefix=current/ so also copy to current/overlays
    if [ -d /boot/firmware/current ]; then
        mkdir -p /boot/firmware/current/overlays 2>/dev/null || true
        cp /tmp/osoyoo-panel-dsi-10inch.dtbo /boot/firmware/current/overlays/ 2>/dev/null || true
        echo "  ✓ 10-inch panel overlay installed (including Ubuntu current/ path)"
    else
        echo "  ✓ 10-inch panel overlay installed"
    fi
    rm /tmp/osoyoo-panel-dsi-10inch.dtbo
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "System Configuration:"
echo "  Model: $PI_MODEL"
echo "  OS: $OS_DISTRO $OS_VERSION"
echo "  Kernel: $KERNEL_VERSION"
echo "  GPIO API: $GPIO_API"
echo ""

# Version compatibility warnings
if [ "$OS_DISTRO" = "ubuntu" ]; then
    UBUNTU_VER_MAJOR=$(echo "$OS_VERSION" | cut -d'.' -f1)
    if [ -n "$UBUNTU_VER_MAJOR" ] && [ "$UBUNTU_VER_MAJOR" -ge 26 ]; then
        echo "NOTE: Ubuntu 26.04+ detected. Driver automatically adapted for your kernel."
        echo ""
    fi
fi

echo "Next Steps  (full table in README.md):"
echo "1. Edit the boot config:  sudo nano /boot/firmware/config.txt"
echo ""
if [ "$OS_DISTRO" = "ubuntu" ]; then
    echo "2. On Ubuntu, make sure these are set:"
    echo "     display_auto_detect=0"
    echo "     dtparam=i2c_arm_baudrate=100000"
    echo ""
    STEP=3
else
    STEP=2
fi
echo "${STEP}. Add the dtoverlay for your panel as the LAST line of config.txt:"
echo ""
if [ "$PANEL_SIZE" = "7inch" ]; then
    echo "     dtoverlay=osoyoo-panel-dsi-7inch"
elif [ "$PANEL_SIZE" = "10inch" ]; then
    case "$PI_MODEL" in
        pi5)
            echo "     # CM5 / Pi 5 - match the DSI port the panel is plugged into:"
            echo "     dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane   # DSI1 (most common)"
            echo "     dtoverlay=osoyoo-panel-dsi-10inch,dsi0,4lane   # DSI0"
            ;;
        *)
            echo "     # Pi 4 / Pi 3 / CM4:"
            echo "     dtoverlay=osoyoo-panel-dsi-10inch"
            ;;
    esac
else
    echo "     7\" 720x1280:                        dtoverlay=osoyoo-panel-dsi-7inch"
    echo "     10.1\" 800x1280 (Pi 4 / Pi 3 / CM4): dtoverlay=osoyoo-panel-dsi-10inch"
    echo "     10.1\" 800x1280 (CM5 / Pi 5, DSI1):  dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane"
    echo "     10.1\" 800x1280 (CM5 / Pi 5, DSI0):  dtoverlay=osoyoo-panel-dsi-10inch,dsi0,4lane"
fi
echo ""
echo "$((STEP+1)). Reboot:  sudo reboot"
echo ""
echo "=========================================="
