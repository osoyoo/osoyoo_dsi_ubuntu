# OSOYOO Raspberry Pi MIPI-DSI Panel Driver

One kernel driver for OSOYOO direct-MIPI-DSI touchscreens on Raspberry Pi. Tested working on
every panel listed below, on **Ubuntu for Raspberry Pi** (24.04 / 26.04) and on **Raspberry Pi OS**.

## Pick the parameter for your screen

`install-direct.sh` takes **one argument** telling it which panel you have. Choose the row that
matches your screen:

| Your screen | Resolution | Run this command |
|---|---|---|
| **10.1 inch** | 800×1280 | `bash install-direct.sh display10inch` |
| **7 inch** | 720×1280 | `bash install-direct.sh display7inch` |
| **3.5 inch** | 480×800 | `bash install-direct.sh display3.5inch` |

That single argument is all you choose — the script auto-detects your board (Pi 3 / 4 / 5), kernel,
OS and boot layout, and picks the correct lane count and overlay for you. (For the 10.1" panel it
uses 2 lanes on Pi 3 / Pi 4 and 4 lanes on Pi 5 / CM5 automatically.)

## Supported screens (details)

| Your panel | `install-direct.sh` argument | `.dts` source file | `dtoverlay=` line | Resolution | Lanes |
|---|---|---|---|---|---|
| 3.5" | `display3.5inch` | `osoyoo-panel-st7701s-3p5inch.dts` | `dtoverlay=osoyoo-panel-st7701s-3p5inch` | 480×800 | 2 |
| 7" | `display7inch` | `osoyoo-panel-dsi-7inch.dts` | `dtoverlay=osoyoo-panel-dsi-7inch` | 720×1280 | 2 |
| 10.1" (Pi 3 / Pi 4) | `display10inch` | `osoyoo-panel-dsi-10inch.dts` | `dtoverlay=osoyoo-panel-dsi-10inch` | 800×1280 | 2 |
| 10.1" (Pi 5 / CM5, 4-lane) | `display10inch` | `osoyoo-panel-dsi-10inch.dts` | `dtoverlay=osoyoo-panel-dsi-10inch,4lane` | 800×1280 | 4 |

The quick-install script only needs the argument from column 2. The remaining columns matter only if
you install by hand (see [Manual installation](#manual-installation)).

Optional overlay parameters (append after a comma, e.g. `...,rotation=90`): `dsi0` (use DSI0 instead
of DSI1), `rotation=90|180|270` (display rotation), `invx` / `invy` / `swapxy` (touch axis fix),
`disable_touch`.

**DSI port note:** the overlays default to **DSI1**. Pi 5 / CM5 / CM4 expose two DSI connectors
(DISP0/DISP1); if the panel is on the **DISP0 / DSI0** port, append `,dsi0`
(e.g. `dtoverlay=osoyoo-panel-dsi-10inch,dsi0`). On Compute Module carriers there is **no DSI
autodetect** — the `dtoverlay=` line must be present in `config.txt`. Pi 5 uses 22-pin DISPLAY
connectors (22→15-pin cable); Pi 4B / 3B+ / 3B / 2B use a 15-pin connector (15→15-pin cable).

## Files

- `osoyoo-dsi-panel.c` → `osoyoo-dsi-panel.ko` — the panel driver (all sizes)
- `osoyoo-panel-regulator.c` → `osoyoo-panel-regulator.ko` — companion device (reset)
- `osoyoo-panel-*.dts` — device-tree overlays
- `install-direct.sh` — one-command build + install (recommended)
- `Makefile`

---

## Quick install (recommended, all OSes)

The script detects your OS, board, kernel and boot layout, installs the build tools and kernel
headers it needs, builds everything, and enables the overlay — one command per panel.

```bash
# Fresh Ubuntu images have no git — install it first (Raspberry Pi OS already has it):
sudo apt update && sudo apt install -y git

git clone https://github.com/osoyoo/osoyoo_dsi_ubuntu.git
cd osoyoo_dsi_ubuntu

# then ONE of these, matching your screen (see the table above):
bash install-direct.sh display10inch     # 10.1"  800x1280
bash install-direct.sh display7inch      # 7"     720x1280
bash install-direct.sh display3.5inch    # 3.5"   480x800
```

Run it as your **normal user** (not `sudo su`); the script calls `sudo` only where root is needed,
so it will ask for your password once. When it finishes, reboot and jump to [Verify](#verify).

> **Ubuntu:** the very first `sudo apt` in the script may need network access to fetch
> `build-essential`, `device-tree-compiler`, and `linux-headers-$(uname -r)`. Make sure the Pi is
> online. That's the only Ubuntu-specific gotcha — the script handles the rest (see
> [Ubuntu notes](#ubuntu-for-raspberry-pi-notes) below).

---

## Manual installation

Prefer the script above. These are the same steps by hand, if you want to understand or customise
them. Run every command from inside the driver folder:

```bash
cd ~/osoyoo_dsi_ubuntu
```

> **Do not use `sudo su` / a root shell.** Build as your normal user; use `sudo` only on the exact
> commands shown with it below. Building as root leaves root-owned files in the folder that make a
> later non-`sudo` command fail with **"Permission denied"** — the single most common install error.

### Step 0 — Install build tools + kernel headers

**Raspberry Pi OS:**

```bash
sudo apt update
sudo apt install -y build-essential device-tree-compiler raspberrypi-kernel-headers
```

**Ubuntu for Raspberry Pi:** (a fresh image has neither a compiler nor the headers)

```bash
sudo apt update
sudo apt install -y build-essential device-tree-compiler linux-headers-$(uname -r)
```

### Step 1 — Build the two kernel modules (normal user, no `sudo`)

```bash
make clean && make
```

This produces `osoyoo-dsi-panel.ko` and `osoyoo-panel-regulator.ko`. Warnings are fine; a failure
here is an error.

### Step 2 — Install the modules

```bash
sudo cp osoyoo-dsi-panel.ko osoyoo-panel-regulator.ko /lib/modules/$(uname -r)/
sudo depmod
```

### Step 3 — Build the overlay **straight into** the boot overlays folder

Set `PANEL` to the `.dts` name from the table (drop the `.dts`). **The overlays folder differs by
OS** — pick the matching command:

```bash
PANEL=osoyoo-panel-dsi-10inch   # or osoyoo-panel-dsi-7inch / osoyoo-panel-st7701s-3p5inch

# Raspberry Pi OS (Bookworm/Trixie):
sudo dtc -@ -I dts -O dtb -o /boot/firmware/overlays/$PANEL.dtbo $PANEL.dts

# Ubuntu for Raspberry Pi (A/B "tryboot" layout — overlays live under current/):
sudo dtc -@ -I dts -O dtb -o /boot/firmware/current/overlays/$PANEL.dtbo $PANEL.dts

# Older Raspberry Pi OS (no /boot/firmware):
sudo dtc -@ -I dts -O dtb -o /boot/overlays/$PANEL.dtbo $PANEL.dts
```

`dtc` prints several `Warning (...)` lines (about `reg_format`, unit addresses, etc.) — **these are
normal and harmless.** The build succeeded as long as the command ends without a `FATAL ERROR`.

Writing the `.dtbo` directly into the boot overlays dir with `sudo` (instead of building a local
copy first and copying it) avoids the classic root-owned-`.dtbo` "Permission denied" trap entirely.

> **Which overlays folder is mine?** Whichever one already contains `vc4-kms-v3d.dtbo`:
> ```bash
> ls /boot/firmware/overlays/vc4-kms-v3d.dtbo \
>    /boot/firmware/current/overlays/vc4-kms-v3d.dtbo \
>    /boot/overlays/vc4-kms-v3d.dtbo 2>/dev/null
> ```
> Put your `.dtbo` in that same folder. (`install-direct.sh` figures this out automatically.)

### Step 4 — Enable the overlay and reboot

Append your panel's `dtoverlay=` line (from the table) to `config.txt`. On Ubuntu and current
Raspberry Pi OS the file is `/boot/firmware/config.txt`; on older Raspberry Pi OS it is
`/boot/config.txt`. Example for the 10.1":

```bash
echo "dtoverlay=osoyoo-panel-dsi-10inch" | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

You edit the top-level `config.txt` even on Ubuntu — the firmware reads it and, via
`os_prefix=current/`, loads the matching overlay from `current/overlays/`.

---

## Verify

After the reboot:

```bash
cat /sys/class/backlight/*/display_name      # should print: DSI-1
```

If it prints `DSI-1`, the driver is bound. You can confirm further with:

```bash
lsmod | grep osoyoo                          # both modules loaded
sudo dmesg | grep -i osoyoo                   # shows the detected panel + lane count
```

The desktop brightness slider is then at **Screen Configuration → Screen → DSI-1 → Brightness**.
Touch follows rotation after you tick the touch device under **Screen Configuration → Screen →
DSI-1 → Touchscreen** and then set the Orientation.

---

## Ubuntu for Raspberry Pi notes

Ubuntu boots the Pi with an **A/B "tryboot" layout**: `/boot/firmware/config.txt` sets
`os_prefix=current/`, and the firmware loads the kernel, device tree **and overlays** from
`/boot/firmware/current/`. Practical consequences:

- **Overlays go in `/boot/firmware/current/overlays/`**, not `/boot/firmware/overlays/` (which
  doesn't exist on Ubuntu). `install-direct.sh` resolves this automatically from `os_prefix`.
- **You still edit the top-level `/boot/firmware/config.txt`** for the `dtoverlay=` line.
- **A fresh Ubuntu image ships no compiler and no kernel headers** — Step 0 above installs
  `build-essential`, `device-tree-compiler` and `linux-headers-$(uname -r)`. It also has no `git`;
  `sudo apt install -y git` first if you're cloning.
- **Kernel upgrades reset things.** When `apt` installs a new kernel it repopulates the boot slots
  (swapping `current/` ↔ `new/`) and creates a new `/lib/modules/<version>/`, so these out-of-tree
  modules and the overlay are dropped. If the panel goes dark after a kernel update, just re-run
  `bash install-direct.sh <screen_name>` to rebuild against the new kernel.

---

## Troubleshooting

**`FATAL ERROR: Couldn't open output file ...dtbo: Permission denied` (Step 3).**
A previous build left a root-owned `.dtbo` in the folder, so a non-`sudo` `dtc` can't overwrite it.
The Step 3 command above avoids this by writing straight to the boot overlays dir with `sudo`.
If you still have a stale local copy, remove it and rebuild:

```bash
sudo rm -f *.dtbo
```

**`display_name` doesn't print `DSI-1` after reboot.**
- Re-check that the `dtoverlay=` line in `config.txt` exactly matches your panel (and, on Pi 5 / CM,
  that you added `,4lane` and/or `,dsi0` as needed — CM carriers have no DSI autodetect).
- Confirm the `.dtbo` landed in the folder the firmware actually reads (on Ubuntu that's
  `/boot/firmware/current/overlays/` — see the Ubuntu notes above).
- Confirm the modules are in place: `ls /lib/modules/$(uname -r)/osoyoo-*.ko`, then `sudo depmod`.
- Look for the panel line in `sudo dmesg | grep -i osoyoo` — it reports the compatible string and
  lane count it bound with.

**`make` fails: `No rule to make target ...` or headers not found.**
Install the kernel headers for the **running** kernel, then rebuild:

```bash
# Ubuntu:
sudo apt update && sudo apt install -y build-essential linux-headers-$(uname -r)
# Raspberry Pi OS:
sudo apt update && sudo apt install -y build-essential raspberrypi-kernel-headers
make clean && make
```

---

## Removing older per-panel drivers

If you previously installed the standalone drivers, remove them so they don't clash with this
unified driver over the same compatible strings:

```bash
sudo rm -f /lib/modules/$(uname -r)/osoyoo-panel-dsi.ko /lib/modules/$(uname -r)/osoyoo-panel-st7701s.ko
sudo depmod
```
