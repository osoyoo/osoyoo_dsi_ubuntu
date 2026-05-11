# OSOYOO DSI Panel Driver for Ubuntu
#OSOYOO 10.1" DSI/Mipi Raspberry Pi touchscreen purchase link:
https://osoyoo.store/products/osoyoo-10-1-ips-dsi-touchscreen-display-for-raspberry-pi-5-4-3-2

Pre-configured driver for OSOYOO DSI panels on Ubuntu 24.04+ for Raspberry Pi 5 / CM5.

**This repository contains Ubuntu-compatible driver sources with all necessary patches already applied. No manual code editing required!**

## Supported Hardware

- **Panels**: OSOYOO 7" and 10.1" DSI touchscreen panels
- **Boards**: Raspberry Pi 3, 4, 5, Compute Module 3, 4, 5
- **OS**: Ubuntu 24.04, Ubuntu 25.10, Ubuntu 26.04+ (auto-detected)
- **Kernels**: 6.8.x, 6.17.x, 7.0.x and newer (auto-patched for compatibility)

## Features

✓ **Auto-detects kernel version** and patches driver for GPIO API compatibility (supports both <6.17 and >=6.17)
✓ **Auto-detects Ubuntu version** (24.04, 25.10, 26.04+) and adapts installation
✓ **Automatic Ubuntu overlay path handling** (`/boot/firmware/current/overlays/`)
✓ **Future-proof**: Works with upcoming Ubuntu versions automatically
 No manual code editing required

## What's New

**Latest Update: Ubuntu 26.04 & Kernel 7.0+ Support**
- ✅ Automatic kernel version detection and code patching
- ✅ Support for kernel 7.0+ (I2C header, backlight API updates)
- ✅ Test detection script to verify compatibility before installation
- ✅ Cleanup script to fix failed installation attempts
- ✅ Enhanced troubleshooting documentation
## Quick Installation (3 Steps)

### Step 1: Install the Driver

```bash
cd ~
sudo apt update
sudo apt install git -y
git clone https://github.com/osoyoo/osoyoo_dsi_ubuntu.git
cd osoyoo_dsi_ubuntu
```

**Optional: Test detection before installing**
```bash
./test-detection.sh
```

This will show you what the installer will detect (OS version, kernel version, GPIO API requirements) without making any changes.

**Install the driver:**
```bash
sudo ./install-direct.sh
```

The installer will automatically:
- Detect your Ubuntu version and kernel version
- Install dependencies (dkms, device-tree-compiler, kernel headers)
- Patch driver code for your kernel's GPIO API (supports kernel 6.8, 6.17, 7.0+)
- Build and install the driver using DKMS
- Copy overlays to the correct Ubuntu paths

### Step 2: Configure config.txt

Edit the boot configuration:

```bash
sudo nano /boot/firmware/config.txt
```

Make these changes:

1. **Find and change** `display_auto_detect=1` to:
   ```
   display_auto_detect=0
   ```

2. **Find** `dtparam=i2c_arm=on` and **add after it**:
   ```
   dtparam=i2c_arm_baudrate=100000
   ```

3. **Add at the end** under `[all]`:

   For 10.1" panel on DSI1 (most CM5 setups):
   ```
   dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane
   ```

   For 10.1" panel on DSI0:
   ```
   dtoverlay=osoyoo-panel-dsi-10inch,dsi0,4lane
   ```

   For 7" panel:
   ```
   dtoverlay=osoyoo-panel-dsi-7inch
   ```

**Example config.txt:**
```ini
[all]
arm_64bit=1
kernel=vmlinuz
dtparam=i2c_arm=on
dtparam=i2c_arm_baudrate=100000
disable_overscan=1
dtoverlay=vc4-kms-v3d
display_auto_detect=0

[all]
dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane
```

Save and exit (Ctrl+X, Y, Enter).

### Step 3: Reboot

```bash
sudo reboot
```

After reboot, your DSI screen should display the Ubuntu desktop! <‰

## Verification

Check if the driver loaded successfully:

```bash
lsmod | grep osoyoo
```

You should see:
```
osoyoo_panel_dsi
osoyoo_panel_regulator
```

## Troubleshooting

### Screen shows nothing (black screen)

1. Check if config.txt has the correct settings:
   ```bash
   grep -E "display_auto_detect|dtoverlay=osoyoo|i2c_arm_baudrate" /boot/firmware/config.txt
   ```

2. Check kernel messages:
   ```bash
   sudo dmesg | grep -i osoyoo
   ```

3. Verify overlay is in place:
   ```bash
   ls -la /boot/firmware/current/overlays/osoyoo*
   ```

### Installation failed with DKMS errors

If installation fails due to previous failed attempts or dpkg errors:

```bash
cd ~/osoyoo_dsi_ubuntu
sudo bash cleanup-and-install.sh
sudo ./install-direct.sh
```

The cleanup script will:
- Remove old broken DKMS modules
- Fix dpkg package state
- Verify kernel headers are installed

### After kernel update, screen stops working

When Ubuntu updates the kernel, reinstall the driver:

```bash
cd ~/osoyoo_dsi_ubuntu
sudo dkms remove osoyoo-dsi-panel/1.0 --all
sudo ./install-direct.sh
sudo reboot
```

### I2C errors in dmesg

Try slower I2C speed in config.txt:
```
dtparam=i2c_arm_baudrate=50000
```

## What's Different from Raspberry Pi OS?

This repository is specifically configured for Ubuntu:

| Feature | Ubuntu (This Repo) | Raspberry Pi OS |
|---------|-------------------|-----------------|
| Driver source | Auto-patched for any kernel version | Original source |
| Kernel detection | Automatic (6.8, 6.17, 6.20+, etc.) | Manual |
| Overlay path | `/boot/firmware/current/overlays/` | `/boot/overlays/` |
| Install script | Auto-detects OS & kernel, patches code | Standard paths only |
| Config hints | Ubuntu-specific instructions | Generic instructions |
| Future-proof | Works with Ubuntu 26.04, 27.x, etc. | N/A |

## Technical Details

### Automatic Kernel Compatibility

The installation script automatically detects your kernel version and patches the driver code accordingly.

**Kernel 6.17+ GPIO API Change:**

Starting with kernel 6.17, the GPIO chip API changed:

**Old API (kernel <6.17):**
```c
void (*set)(struct gpio_chip *chip, unsigned offset, int value);
```

**New API (kernel ≥6.17):**
```c
int (*set)(struct gpio_chip *chip, unsigned offset, int value);
```

**How it works:**
1. The installer detects your kernel version (e.g., 6.8.x, 6.17.x, 7.0.x)
2. Automatically patches driver code with the correct APIs for your kernel
3. Builds the driver for your specific kernel

**Kernel 7.0+ additional fixes:**
- Added `#include <linux/i2c.h>` for I2C API support
- Updated backlight API (replaced FB_BLANK_UNBLANK)

This means the driver works on **any** Ubuntu version, present or future, without manual code editing.

### Ubuntu Boot Path

Ubuntu uses `os_prefix=current/` in config.txt, which tells the firmware to load overlays from:
```
/boot/firmware/current/overlays/
```

Instead of the standard:
```
/boot/firmware/overlays/
```

The install script automatically handles this.

## Hardware Connection

### For CM5 with 10.1" panel:

```
CM5 DSI1 Port ’ OSOYOO 10.1" Panel DSI connector
```

Use: `dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane`

### For Pi 5 with 10.1" panel:

```
Pi 5 DSI Port ’ OSOYOO 10.1" Panel DSI connector
```

Use: `dtoverlay=osoyoo-panel-dsi-10inch,dsi0,4lane`

## Support

- **Issues**: https://github.com/osoyoo/osoyoo_dsi_ubuntu/issues
- **Email**: support@osoyoo.info
- **Original Repository**: https://github.com/osoyoo/osoyoo-dsi-panel

## Documentation

- **[UBUNTU-INSTALL-GUIDE.md](UBUNTU-INSTALL-GUIDE.md)** - Detailed installation guide with technical explanations

## License

GPL (same as original driver)

## Credits

- **Original Driver**: OSOYOO
- **Ubuntu Compatibility**: Community contribution
- **Testing**: Ubuntu 25.10 (Questing Quokka) on CM5

---

**Note**: If you're using Raspberry Pi OS instead of Ubuntu, use the original repository: https://github.com/osoyoo/osoyoo-dsi-panel
