# OSOYOO DSI Panel Driver - Installation Guide

Easy installation guide for OSOYOO 7" and 10.1" DSI touchscreen panels on Raspberry Pi.

## What's New?

This driver now uses **DKMS** (Dynamic Kernel Module Support), which means:
- ✅ **Automatic updates** - Driver rebuilds automatically when kernel updates
- ✅ **No manual compilation** - Install once and forget
- ✅ **Easy installation** - Simple `apt install` command

## Installation

### Method 1: Using APT (Recommended)

If available from a repository:

```bash
# Add the OSOYOO repository (if available via APT)
echo "deb [trusted=yes] https://osoyoo.github.io/osoyoo-dsi-panel/ ./" | \
    sudo tee /etc/apt/sources.list.d/osoyoo.list

# Update and install
sudo apt update
sudo apt install osoyoo-dsi-panel-dkms
```

### Method 2: Manual Installation

Download and install the `.deb` package:

```bash
# Download the package
wget https://github.com/osoyoo/osoyoo-dsi-panel/releases/download/v1.0/osoyoo-dsi-panel-dkms_1.0-1_all.deb

# Install the package
sudo dpkg -i osoyoo-dsi-panel-dkms_1.0-1_all.deb

# Install dependencies if needed
sudo apt-get install -f
```

## Configuration

After installation, you need to enable the display overlay:

### Step 1: Edit Config File

Edit your Raspberry Pi configuration file:

```bash
# For newer Raspberry Pi OS:
sudo nano /boot/firmware/config.txt

# OR for older versions:
sudo nano /boot/config.txt
```

### Step 2: Add Display Overlay

Add **ONE** of the following lines at the end of the file:

**For 7-inch panel:**
```
dtoverlay=osoyoo-panel-dsi-7inch
```

**For 10.1-inch panel (2-lane mode):**
```
dtoverlay=osoyoo-panel-dsi-10inch
```

**For 10.1-inch panel (4-lane mode):**
```
dtoverlay=osoyoo-panel-dsi-10inch,4lane
```

### Step 3: Reboot

```bash
sudo reboot
```

## Verification

After reboot, check if the driver is loaded:

```bash
# Check if modules are loaded
lsmod | grep osoyoo

# You should see:
# osoyoo_panel_dsi
# osoyoo_panel_regulator
```

## Automatic Updates

That's it! From now on:
- When you run `sudo apt upgrade`, the kernel may update
- **The driver will automatically rebuild** for the new kernel
- No manual intervention needed!

## Uninstallation

To remove the driver:

```bash
# Remove package (keeps configuration)
sudo apt remove osoyoo-dsi-panel-dkms

# OR completely purge (removes everything)
sudo apt purge osoyoo-dsi-panel-dkms
```

**Don't forget to:**
1. Remove the `dtoverlay` line from `/boot/config.txt` or `/boot/firmware/config.txt`
2. Reboot

## Troubleshooting

### Display not working after installation

1. **Check config file:**
   ```bash
   grep osoyoo /boot/config.txt /boot/firmware/config.txt
   ```
   Make sure the `dtoverlay` line is present and uncommented

2. **Check driver status:**
   ```bash
   dkms status osoyoo-dsi-panel
   ```
   Should show: `osoyoo-dsi-panel/1.0, 6.x.x, arm64: installed`

3. **Check modules:**
   ```bash
   lsmod | grep osoyoo
   ```

4. **Manually load modules:**
   ```bash
   sudo modprobe osoyoo-panel-regulator
   sudo modprobe osoyoo-panel-dsi
   ```

5. **Check kernel logs:**
   ```bash
   dmesg | grep -i osoyoo
   dmesg | grep -i dsi
   ```

### After kernel update, display stopped working

This shouldn't happen with DKMS, but if it does:

```bash
# Rebuild driver
sudo dkms build -m osoyoo-dsi-panel -v 1.0
sudo dkms install -m osoyoo-dsi-panel -v 1.0
sudo reboot
```

### Check installed version

```bash
dpkg -l | grep osoyoo
```

## Support

For issues, please report:
- Raspberry Pi model
- Raspberry Pi OS version (`cat /etc/os-release`)
- Kernel version (`uname -r`)
- Panel size (7" or 10.1")
- Output of `dkms status` and `dmesg | grep osoyoo`

## Old Manual Installation Method

If you prefer the old manual method (not recommended):

```bash
# Build manually
make
sudo cp ./osoyoo-panel-regulator.ko /lib/modules/$(uname -r)
sudo cp ./osoyoo-panel-dsi.ko /lib/modules/$(uname -r)
sudo depmod
sudo modprobe osoyoo-panel-regulator
sudo modprobe osoyoo-panel-dsi

# Device tree overlays
sudo dtc -I dts -O dtb -o osoyoo-panel-dsi-7inch.dtbo osoyoo-panel-dsi-7inch.dts
sudo cp osoyoo-panel-dsi-7inch.dtbo /boot/overlays/
```

**Note:** With manual installation, you'll need to rebuild after every kernel update!
