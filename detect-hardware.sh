#!/bin/bash
# Hardware detection script for Raspberry Pi
# Outputs: PI_MODEL, OS_DISTRO, KERNEL_VERSION

# Detect Raspberry Pi Model
detect_pi_model() {
    local model=""

    # Check /proc/device-tree/model
    if [ -f /proc/device-tree/model ]; then
        local device_model=$(cat /proc/device-tree/model | tr -d '\0')

        case "$device_model" in
            *"Raspberry Pi 5"*|*"Raspberry Pi Compute Module 5"*)
                model="pi5"
                ;;
            *"Raspberry Pi 4"*|*"Raspberry Pi Compute Module 4"*)
                model="pi4"
                ;;
            *"Raspberry Pi 3"*|*"Raspberry Pi Compute Module 3"*)
                model="pi3"
                ;;
            *)
                # Try /proc/cpuinfo as fallback
                if grep -q "BCM2712" /proc/cpuinfo; then
                    model="pi5"
                elif grep -q "BCM2711" /proc/cpuinfo; then
                    model="pi4"
                elif grep -q "BCM2837" /proc/cpuinfo; then
                    model="pi3"
                else
                    model="unknown"
                fi
                ;;
        esac
    fi

    echo "$model"
}

# Detect OS Distribution
detect_os_distro() {
    local distro=""

    if [ -f /etc/os-release ]; then
        . /etc/os-release

        case "$ID" in
            raspbian|debian)
                distro="debian"
                ;;
            ubuntu)
                distro="ubuntu"
                ;;
            *)
                distro="$ID"
                ;;
        esac
    else
        distro="unknown"
    fi

    echo "$distro"
}

# Detect Kernel Version
detect_kernel_version() {
    uname -r
}

# Detect Architecture
detect_arch() {
    uname -m
}

# Main detection function
detect_all() {
    local pi_model=$(detect_pi_model)
    local os_distro=$(detect_os_distro)
    local kernel_version=$(detect_kernel_version)
    local arch=$(detect_arch)

    echo "PI_MODEL=$pi_model"
    echo "OS_DISTRO=$os_distro"
    echo "KERNEL_VERSION=$kernel_version"
    echo "ARCH=$arch"
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_all
fi
