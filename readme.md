# OSOYOO DSI Panel Driver for Ubuntu

Driver + device-tree overlays for the **OSOYOO DSI touch displays** on Raspberry Pi
running **Ubuntu** (Raspberry Pi 3 / 4 / 5 and CM3 / CM4 / CM5).

- OSOYOO 7" DSI touchscreen (720×1280) — https://osoyoo.store/products/7-dsi-ips-720-1280-hd-capacitive-touchscreen-for-raspberry-pi-5-4b-3b-3a-dsi-gpio-powered-5-point-touch-6h-hardness-tempered-glass-anti-fingerprint
- OSOYOO 10.1" DSI touchscreen (800×1280) — https://osoyoo.store/products/osoyoo-10-1-ips-dsi-touchscreen-display-for-raspberry-pi-5-4-3-2

The driver builds on any Ubuntu kernel (6.8, 6.17, 7.0 and newer). The source is
version-guarded for the kernel 6.17+ GPIO API change, so **no code editing or runtime
patching is needed** — DKMS just builds it for your kernel.

## Install

```bash
sudo apt update
sudo apt install git -y
git clone https://github.com/osoyoo/osoyoo_dsi_ubuntu.git
cd osoyoo_dsi_ubuntu
sudo ./install-direct.sh 7inch      # for the 720x1280  7"    screen
# or
sudo ./install-direct.sh 10inch     # for the 800x1280  10.1" screen
```

`install-direct.sh` automatically:
- installs the build dependencies (`dkms`, `device-tree-compiler`, `i2c-tools`, matching kernel headers),
- detects your Raspberry Pi model and kernel,
- builds and installs the driver with DKMS (so it rebuilds on kernel updates), and
- installs the device-tree overlays (into Ubuntu's `current/overlays/` path).

It does **not** edit `config.txt` — you do that once, in the next step.

## Configure `config.txt`

Edit the boot config:

```bash
sudo nano /boot/firmware/config.txt
```

On Ubuntu, set these two (change `display_auto_detect=1` to `0`, and add the baudrate
line near the other `dtparam=i2c_arm` line):

```
display_auto_detect=0
dtparam=i2c_arm_baudrate=100000
```

Then add **exactly one** `dtoverlay` line as the **last line** of the file, for your panel:

### 1. For the 7" (720×1280) screen

```
dtoverlay=osoyoo-panel-dsi-7inch
```

### 2. For the 10.1" (800×1280) screen

**CM5 / Raspberry Pi 5** — match the DSI port the panel is plugged into:

- plugged into **DSI0**:
  ```
  dtoverlay=osoyoo-panel-dsi-10inch,dsi0,4lane
  ```
- plugged into **DSI1**:
  ```
  dtoverlay=osoyoo-panel-dsi-10inch,dsi1,4lane
  ```

**CM4 / Raspberry Pi 4 / Raspberry Pi 3**:

```
dtoverlay=osoyoo-panel-dsi-10inch
```

> Why the difference: Pi 3/4 use a 2-lane DSI connector, while CM5/Pi 5 use 4 lanes and
> expose two DSI ports (DSI0/DSI1). The plain `osoyoo-panel-dsi-10inch` overlay is 2-lane
> on DSI1 by default; the `,4lane` and `,dsi0`/`,dsi1` parameters select the CM5/Pi 5 setup.

Save (Ctrl+X, Y, Enter) and reboot:

```bash
sudo reboot
```

After reboot the panel shows the Ubuntu desktop.

## Verify

```bash
lsmod | grep osoyoo                        # -> osoyoo_panel_dsi, osoyoo_panel_regulator
cat /sys/class/drm/card*-DSI-1/status      # -> connected
sudo dmesg | grep -i osoyoo                # -> "osoyoo panel." + "lanes: N"
```

## Troubleshooting

**`Error! DKMS tree already contains: osoyoo-dsi-panel/1.0`**
A previous run is still registered. Clear it and re-run:

```bash
sudo dkms remove osoyoo-dsi-panel/1.0 --all
sudo ./install-direct.sh 10inch
```

**Panel is black after a kernel / system upgrade.**
Ubuntu upgrades kernels regularly, and DKMS can only rebuild the module for a new kernel
if that kernel's headers are installed. Install the matching headers (this triggers the
DKMS rebuild automatically), then reboot:

```bash
sudo apt-get install -y linux-headers-$(uname -r)
sudo dkms autoinstall
sudo reboot
```

**Black screen right after install.**
Double-check the `dtoverlay` line matches your board and DSI port (see the table above),
and that `display_auto_detect=0` is set. On Pi 3/4 use the plain 2-lane line — the
`,4lane` variants are for CM5/Pi 5 only. Also make sure the DSI ribbon is fully seated and
the right way round at both ends.

**I2C errors in `dmesg`.**
Try a slower I2C speed in `config.txt`: `dtparam=i2c_arm_baudrate=50000`.

## Uninstall

```bash
sudo dkms remove osoyoo-dsi-panel/1.0 --all
```

Then remove the `dtoverlay=osoyoo-panel-dsi-*` line from `/boot/firmware/config.txt` and reboot.

## Notes

- Ubuntu loads overlays from `/boot/firmware/current/overlays/` (because of `os_prefix=current/`);
  the installer copies the overlays there for you.
- Using Raspberry Pi OS instead of Ubuntu? Use the original repo:
  https://github.com/osoyoo/osoyoo-dsi-panel

## License

GPL (same as the original driver).
