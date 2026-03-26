# Ubuntu Installation Guide for OSOYOO DSI Panel

This guide explains how to install the OSOYOO 10.1" DSI panel driver on Ubuntu 24.04+ for Raspberry Pi 5 / CM5.

## Important Notes

- **Ubuntu kernel compatibility**: Ubuntu 25.10 uses kernel 6.17+ which requires driver patches
- **Overlay path**: Ubuntu uses `os_prefix=current/` requiring overlays in `/boot/firmware/current/overlays/`
- **This guide was tested on**: Ubuntu 25.10 (Questing Quokka) with kernel 6.17.0-1003-raspi

## Prerequisites

- Raspberry Pi 5 or Compute Module 5
- Ubuntu 24.04 or newer installed
- OSOYOO 10.1" DSI panel connected to DSI0 or DSI1 port
- Internet connection
- Root/sudo access

## Step 1: Clone the Repository

```bash
cd ~
git clone https://github.com/osoyoo/osoyoo-dsi-panel.git
cd osoyoo-dsi-panel
```

## Step 2: Fix Kernel 6.17+ GPIO API Compatibility

Ubuntu 25.10 uses kernel 6.17 which changed the GPIO API. The `gpio_chip->set` function now returns `int` instead of `void`.

Edit the driver source file:

```bash
nano src/pi5/osoyoo-panel-regulator.c
```

Find line 41 and change:
```c
static void osoyoo_panel_gpio_set(struct gpio_chip *gc, unsigned int off, int val)
```

To:
```c
static int osoyoo_panel_gpio_set(struct gpio_chip *gc, unsigned int off, int val)
```

Find line 47 and change:
```c
	if (off >= NUM_GPIO)
		return;
```

To:
```c
	if (off >= NUM_GPIO)
		return 0;
```

Find line 61 (after `mutex_unlock(&state->lock);`) and add:
```c
	return 0;
```

The complete fixed function should look like:
```c
static int osoyoo_panel_gpio_set(struct gpio_chip *gc, unsigned int off, int val)
{
	struct osoyoo_panel_lcd *state = gpiochip_get_data(gc);
	u8 last_val;

	if (off >= NUM_GPIO)
		return 0;

	mutex_lock(&state->lock);

	last_val = state->poweron_state;
	if (val)
		last_val |= (1 << off);
	else
		last_val &= ~(1 << off);

	state->poweron_state = last_val;

	regmap_write(state->regmap, REG_POWERON, last_val);

	mutex_unlock(&state->lock);
	return 0;
}
```

Save and exit (Ctrl+X, Y, Enter).

**Note**: For kernel 6.8 and earlier, this patch is not needed.

## Step 3: Install the Driver

Run the installation script:

```bash
sudo ./install-direct.sh
```

The script will:
- Install dependencies (dkms, device-tree-compiler, kernel headers)
- Auto-detect your Pi model (CM5/Pi 5)
- Build and install the driver using DKMS
- Compile and install device tree overlays to `/boot/firmware/overlays/`

## Step 4: Copy Overlays to Ubuntu Boot Path

Ubuntu uses `os_prefix=current/` which means it looks for overlays in `/boot/firmware/current/overlays/`. Copy the overlays there:

```bash
sudo mkdir -p /boot/firmware/current/overlays
sudo cp /boot/firmware/overlays/osoyoo-panel-dsi-10inch.dtbo /boot/firmware/current/overlays/
sudo cp /boot/firmware/overlays/osoyoo-panel-dsi-7inch.dtbo /boot/firmware/current/overlays/
```

## Step 5: Configure config.txt

Edit the boot configuration:

```bash
sudo nano /boot/firmware/config.txt
```

Make the following changes:

### 1. Disable display auto-detection

Find the line:
```
display_auto_detect=1
```

Change it to:
```
display_auto_detect=0
```

### 2. Add I2C speed configuration

Find the line:
```
dtparam=i2c_arm=on
```

Add immediately after it:
```
dtparam=i2c_arm_baudrate=100000
```

### 3. Add the panel overlay

At the end of the file under `[all]`, add ONE of these lines:

**For 10.1" panel on DSI1 (CM5 most common):**
```
dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane
```

**For 10.1" panel on DSI0:**
```
dtoverlay=osoyoo-panel-dsi-10inch,dsi0,4lane
```

**For 7" panel:**
```
dtoverlay=osoyoo-panel-dsi-7inch
```

### Example config.txt section:

```ini
[all]
arm_64bit=1
kernel=vmlinuz
cmdline=cmdline.txt
initramfs initrd.img followkernel
dtparam=audio=on
dtparam=i2c_arm=on
dtparam=i2c_arm_baudrate=100000
dtparam=spi=on
disable_overscan=1
dtoverlay=vc4-kms-v3d
disable_fw_kms_setup=1
camera_auto_detect=1
display_auto_detect=0

[all]
dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane
```

Save and exit.

## Step 6: Reboot

```bash
sudo reboot
```

After reboot, the DSI screen should display the Ubuntu desktop.

## Verification

After reboot, verify the driver loaded correctly:

```bash
# Check if modules are loaded
lsmod | grep osoyoo

# Should show:
# osoyoo_panel_dsi
# osoyoo_panel_regulator

# Check DKMS status
dkms status osoyoo-dsi-panel

# Should show:
# osoyoo-dsi-panel/1.0, 6.17.0-1003-raspi, aarch64: installed
```

## Troubleshooting

### Screen shows nothing (black screen)

1. **Check if overlay was loaded**:
   ```bash
   ls -la /boot/firmware/current/overlays/osoyoo*
   ```
   If missing, repeat Step 4.

2. **Check kernel messages**:
   ```bash
   sudo dmesg | grep -i osoyoo
   ```

   Look for errors like:
   - `Failed to read id: -5` = I2C communication failure
   - `deferred probe pending` = Driver waiting for I2C device

3. **Verify I2C device appears**:
   ```bash
   ls /sys/bus/i2c/devices/
   ```
   Should show `10-0045` (display controller) and `10-005d` (touchscreen).

4. **Check I2C communication**:
   ```bash
   sudo apt install i2c-tools
   sudo i2cdetect -y 10
   ```
   Should show devices at 0x45 and 0x5d.

### Build fails with "incompatible pointer type" error

You're running kernel 6.17+ and need to apply the GPIO API fix from Step 2.

### After kernel update, screen stops working

When Ubuntu updates the kernel, DKMS should automatically rebuild the driver. If not:

```bash
cd ~/osoyoo-dsi-panel
sudo dkms remove osoyoo-dsi-panel/1.0 --all
sudo ./install-direct.sh
sudo cp /boot/firmware/overlays/osoyoo-panel-dsi-*.dtbo /boot/firmware/current/overlays/
sudo reboot
```

### Wrong I2C speed

If you see I2C errors, try slower speed in config.txt:

```
dtparam=i2c_arm_baudrate=50000
```

### Display auto-detect interference

Make sure `display_auto_detect=0` is set. Ubuntu's auto-detection can conflict with manual overlays.

## Differences from Raspberry Pi OS

| Aspect | Raspberry Pi OS | Ubuntu |
|--------|----------------|--------|
| Overlay path | `/boot/overlays/` | `/boot/firmware/current/overlays/` |
| Kernel headers | `raspberrypi-kernel-headers` | `linux-headers-$(uname -r)` |
| Kernel version | 6.6-6.8 (stable API) | 6.17+ (breaking changes) |
| Boot prefix | None | `os_prefix=current/` |
| Display auto-detect | Works with manual overlays | Must disable (`=0`) |

## Kernel Version Compatibility

- **Kernel 6.6-6.8**: No patches needed, driver works as-is
- **Kernel 6.17+**: Requires GPIO API patch (Step 2)
- **Future kernels**: May require additional patches

## Technical Details

### Why the GPIO patch is needed

Kernel 6.17 changed the GPIO chip `set` callback from:
```c
void (*set)(struct gpio_chip *chip, unsigned offset, int value);
```

To:
```c
int (*set)(struct gpio_chip *chip, unsigned offset, int value);
```

This allows error reporting from GPIO operations.

### Why overlays go in current/overlays/

Ubuntu's firmware config uses:
```ini
[all]
os_prefix=current/
```

This tells the bootloader to look in `/boot/firmware/current/` for kernel, overlays, etc. This supports A/B boot partitions for atomic updates.

### I2C bus numbering

- **DSI0**: Uses I2C bus 0 (`i2c-0`)
- **DSI1**: Uses I2C bus 10 (`i2c-10`) on CM5
- The display controller is at I2C address `0x45`
- The touchscreen (Goodix GT9271) is at `0x5d`

## Support

- GitHub Issues: https://github.com/osoyoo/osoyoo-dsi-panel/issues
- Email: support@osoyoo.info

## Credits

Driver developed by OSOYOO.
Ubuntu compatibility guide created through community testing.
