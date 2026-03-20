# Hardware Detection and Model-Specific Drivers

This package includes automatic hardware detection that selects the appropriate driver based on your Raspberry Pi model.

## Overview

The installer automatically:
1. Detects your Raspberry Pi model (Pi 3, Pi 4, or Pi 5)
2. Detects your OS distribution (Debian, Ubuntu, etc.)
3. Detects your kernel version
4. Selects and installs the appropriate driver variant

## Directory Structure

```
src/
├── pi3/          # Raspberry Pi 3 specific drivers
│   ├── osoyoo-panel-dsi.c
│   ├── osoyoo-panel-regulator.c
│   ├── osoyoo-panel-dsi-7inch.dts
│   └── osoyoo-panel-dsi-10inch.dts
├── pi4/          # Raspberry Pi 4 / CM4 specific drivers
│   ├── osoyoo-panel-dsi.c
│   ├── osoyoo-panel-regulator.c
│   ├── osoyoo-panel-dsi-7inch.dts
│   └── osoyoo-panel-dsi-10inch.dts
└── pi5/          # Raspberry Pi 5 specific drivers
    ├── osoyoo-panel-dsi.c
    ├── osoyoo-panel-regulator.c
    ├── osoyoo-panel-dsi-7inch.dts
    └── osoyoo-panel-dsi-10inch.dts
```

## How Detection Works

### Hardware Detection

The installer detects hardware in the following order:

1. **Raspberry Pi Model**: Reads `/proc/device-tree/model`
   - Raspberry Pi 5 → uses `src/pi5/` sources
   - Raspberry Pi 4 / CM4 → uses `src/pi4/` sources
   - Raspberry Pi 3 → uses `src/pi3/` sources

2. **Fallback Detection**: If model detection fails, checks `/proc/cpuinfo` for:
   - BCM2712 → Raspberry Pi 5
   - BCM2711 → Raspberry Pi 4
   - BCM2837 → Raspberry Pi 3

3. **OS Distribution**: Reads `/etc/os-release` to identify:
   - Raspbian/Debian
   - Ubuntu
   - Other distributions

4. **Kernel Version**: Uses `uname -r`

### Installation Process

```
┌──────────────────────────────┐
│  Package Installation Start  │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│   Detect Hardware (postinst) │
│  - Pi Model                  │
│  - OS Distribution           │
│  - Kernel Version            │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│  Select Source Directory     │
│   /usr/src/.../src/piX/      │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│  Copy Selected Sources       │
│   to DKMS build directory    │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│   DKMS Build & Install       │
│   - Add to DKMS              │
│   - Build module             │
│   - Install module           │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│  Install Device Tree         │
│  Overlays                    │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│    Installation Complete!    │
└──────────────────────────────┘
```

## Fallback Logic

If no exact match is found for your Pi model:

1. Tries Pi 4 driver (most common)
2. Falls back to Pi 3 driver
3. Fails with error message if no drivers available

## Customizing Model-Specific Drivers

### For Developers

To customize drivers for specific models:

1. **Navigate to the model directory:**
   ```bash
   cd src/pi4/  # or pi3, pi5
   ```

2. **Modify the source files:**
   - `osoyoo-panel-dsi.c` - Main DSI panel driver
   - `osoyoo-panel-regulator.c` - Regulator driver
   - `osoyoo-panel-dsi-7inch.dts` - 7" panel device tree
   - `osoyoo-panel-dsi-10inch.dts` - 10.1" panel device tree

3. **Add model-specific code:**
   ```c
   #ifdef CONFIG_ARCH_BCM2711  // Pi 4
       // Pi 4 specific code
   #elif defined(CONFIG_ARCH_BCM2712)  // Pi 5
       // Pi 5 specific code
   #else  // Pi 3
       // Pi 3 specific code
   #endif
   ```

4. **Rebuild the package:**
   ```bash
   ./build-deb-manual.sh
   ```

## Installation Output Example

```
==========================================
OSOYOO DSI Panel Driver Installation
==========================================

Detecting hardware...
  Raspberry Pi Model: pi4
  OS Distribution: debian
  Kernel Version: 6.6.51+rpt-rpi-v8
  Architecture: aarch64

Using model-specific driver: /usr/src/osoyoo-dsi-panel-1.0/src/pi4

Copying model-specific source files...
Adding module to DKMS...
Building driver for kernel 6.6.51+rpt-rpi-v8...
Build successful!
Installing driver module...
Installation successful!

Installing device tree overlays...
  ✓ 7-inch panel overlay installed
  ✓ 10-inch panel overlay installed

==========================================
Installation Complete!
==========================================
```

## Testing Different Models

### Manual Testing

To test which driver would be selected on your system:

```bash
# Check your Pi model
cat /proc/device-tree/model

# Check CPU info
grep "^Model" /proc/cpuinfo

# Check kernel version
uname -r

# Check OS
cat /etc/os-release
```

### Simulating Detection

```bash
# Source the detection script
source detect-hardware.sh

# Run detection
detect_all
```

Output example:
```
PI_MODEL=pi4
OS_DISTRO=debian
KERNEL_VERSION=6.6.51+rpt-rpi-v8
ARCH=aarch64
```

## Troubleshooting

### Driver Not Found

If you see:
```
ERROR: No compatible driver found for your Raspberry Pi model.
```

**Solution:**
1. Check your Pi model: `cat /proc/device-tree/model`
2. Verify package contains required files:
   ```bash
   dpkg -L osoyoo-dsi-panel-dkms | grep "src/pi"
   ```
3. Manually specify a driver:
   ```bash
   sudo cp /usr/src/osoyoo-dsi-panel-1.0/src/pi4/*.c /usr/src/osoyoo-dsi-panel-1.0/
   sudo cp /usr/src/osoyoo-dsi-panel-1.0/src/pi4/*.dts /usr/src/osoyoo-dsi-panel-1.0/
   sudo dkms install osoyoo-dsi-panel/1.0
   ```

### Wrong Driver Selected

If the wrong driver was auto-selected:

1. **Remove the package:**
   ```bash
   sudo apt remove osoyoo-dsi-panel-dkms
   ```

2. **Manually install correct driver:**
   ```bash
   # Extract package
   dpkg -x osoyoo-dsi-panel-dkms_1.0-1_all.deb /tmp/osoyoo

   # Copy desired model sources
   sudo cp -r /tmp/osoyoo/usr/src/osoyoo-dsi-panel-1.0 /usr/src/
   sudo cp /usr/src/osoyoo-dsi-panel-1.0/src/pi5/*.c /usr/src/osoyoo-dsi-panel-1.0/
   sudo cp /usr/src/osoyoo-dsi-panel-1.0/src/pi5/*.dts /usr/src/osoyoo-dsi-panel-1.0/

   # Build and install
   sudo dkms add -m osoyoo-dsi-panel -v 1.0
   sudo dkms build -m osoyoo-dsi-panel -v 1.0
   sudo dkms install -m osoyoo-dsi-panel -v 1.0
   ```

### Build Failures

If DKMS build fails:

```bash
# Install kernel headers
sudo apt-get install raspberrypi-kernel-headers

# Retry build
sudo dkms build -m osoyoo-dsi-panel -v 1.0
sudo dkms install -m osoyoo-dsi-panel -v 1.0
```

## Advanced Configuration

### Adding Support for New Models

To add support for a new Raspberry Pi model:

1. **Create source directory:**
   ```bash
   mkdir src/pi6  # for hypothetical Pi 6
   ```

2. **Copy and modify sources:**
   ```bash
   cp src/pi5/*.* src/pi6/
   # Edit files for pi6 specific changes
   ```

3. **Update postinst detection** in `debian/postinst`:
   ```bash
   case "$device_model" in
       *"Raspberry Pi 6"*)
           pi_model="pi6"
           ;;
       ...
   ```

4. **Rebuild package:**
   ```bash
   ./build-deb-manual.sh
   ```

## Support

For issues related to hardware detection:
- Check detection output during installation
- Verify your Pi model is supported
- Report issues at: https://github.com/osoyoo/osoyoo-dsi-panel/issues
- Email: support@osoyoo.info
