#!/usr/bin/env bash
#
# install-direct.sh — build + install the OSOYOO unified MIPI-DSI panel driver
#
# Usage:
#   ./install-direct.sh <screen_name>
#
#   screen_name is one of:
#     display10inch    10.1"  (800x1280)  osoyoo-panel-dsi-10inch
#     display7inch     7"     (720x1280)  osoyoo-panel-dsi-7inch
#     display3.5inch   3.5"   (480x800)   osoyoo-panel-st7701s-3p5inch
#
# What it does, automatically:
#   1) Installs the build tools + kernel headers it needs (build-essential,
#      device-tree-compiler, linux-headers for the RUNNING kernel) if missing.
#   2) Detects the running kernel and builds the modules against ITS headers.
#   3) Picks the right .dts / .dtbo file names for the chosen screen.
#   4) Installs the modules, builds the overlay into the correct boot overlays
#      dir, and sets the matching  dtoverlay=...  line in config.txt (idempotently).
#
# Works on Raspberry Pi OS (Bookworm/Trixie: /boot/firmware, older: /boot) AND
# on Ubuntu for Raspberry Pi (24.04/26.04), whose A/B "tryboot" layout keeps the
# kernel, dtb and overlays under /boot/firmware/current/  (os_prefix=current/).
#
# Run it as your NORMAL user (it uses sudo only where root is required).

set -euo pipefail

# --------------------------------------------------------------------------
# 0. Locate ourselves + the source tree
# --------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo ">> $*"; }

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <screen_name>

  screen_name:
    display10inch     10.1"  panel
    display7inch      7"     panel
    display3.5inch    3.5"   panel
EOF
  exit 1
}

[ $# -eq 1 ] || usage

# --------------------------------------------------------------------------
# 1. Map screen_name -> overlay base name (the .dts/.dtbo share this stem)
# --------------------------------------------------------------------------
case "$1" in
  display10inch|display10|10inch|10.1inch)
      PANEL="osoyoo-panel-dsi-10inch";        LABEL="10.1\"" ;;
  display7inch|display7|7inch)
      PANEL="osoyoo-panel-dsi-7inch";         LABEL="7\"" ;;
  display3.5inch|display3p5inch|3.5inch|3p5inch)
      PANEL="osoyoo-panel-st7701s-3p5inch";   LABEL="3.5\"" ;;
  *)
      echo "Unknown screen_name: '$1'" >&2
      usage ;;
esac

DTS_FILE="$SCRIPT_DIR/$PANEL.dts"
[ -f "$DTS_FILE" ] || die "device-tree source not found: $DTS_FILE"
[ -f "$SCRIPT_DIR/Makefile" ] || die "Makefile not found in $SCRIPT_DIR — run this from the driver folder."

# --------------------------------------------------------------------------
# 2. Detect boot layout
#    Raspberry Pi OS (Bookworm/Trixie) & Ubuntu use /boot/firmware; older
#    Raspberry Pi OS uses /boot.
# --------------------------------------------------------------------------
if [ -f /boot/firmware/config.txt ]; then
  BOOT_DIR="/boot/firmware"
elif [ -f /boot/config.txt ]; then
  BOOT_DIR="/boot"
else
  die "Could not find config.txt (/boot/firmware/config.txt or /boot/config.txt)."
fi
CONFIG_TXT="$BOOT_DIR/config.txt"

# --------------------------------------------------------------------------
# 2b. Resolve the overlays dir the firmware actually loads from.
#     * Standard Raspberry Pi OS:          $BOOT_DIR/overlays
#     * Ubuntu A/B "tryboot" layout:       $BOOT_DIR/<os_prefix>overlays
#       (config.txt carries `os_prefix=current/`; the firmware prepends that
#        prefix to the kernel, dtb AND overlays it loads, so the .dtbo must
#        live in .../current/overlays/, NOT .../overlays/.)
# --------------------------------------------------------------------------
resolve_overlays_dir() {
  # 1) Plain layout
  if [ -d "$BOOT_DIR/overlays" ]; then
    echo "$BOOT_DIR/overlays"; return 0
  fi
  # 2) Follow the ACTIVE (non-[tryboot]) os_prefix from config.txt
  local prefix
  prefix="$(awk '
    /^[[:space:]]*\[tryboot\]/ { intry=1; next }
    /^[[:space:]]*\[/          { intry=0 }
    !intry && /^[[:space:]]*os_prefix=/ {
        line=$0; sub(/^[^=]*=[[:space:]]*/, "", line); gsub(/[[:space:]]/, "", line); p=line
    }
    END { print p }' "$CONFIG_TXT" 2>/dev/null)"
  if [ -n "$prefix" ] && [ -d "$BOOT_DIR/${prefix}overlays" ]; then
    echo "$BOOT_DIR/${prefix}overlays"; return 0
  fi
  # 3) Last resort: the first */overlays under the boot dir
  local cand
  cand="$(find "$BOOT_DIR" -maxdepth 2 -type d -name overlays 2>/dev/null | head -n1)"
  [ -n "$cand" ] && { echo "$cand"; return 0; }
  return 1
}

OVERLAYS_DIR="$(resolve_overlays_dir)" \
  || die "Could not find an overlays dir under $BOOT_DIR (looked for overlays/, <os_prefix>overlays/)."
note "Boot dir     : $BOOT_DIR"
note "Overlays dir : $OVERLAYS_DIR"
note "config.txt   : $CONFIG_TXT"

# --------------------------------------------------------------------------
# 3. Decide the dtoverlay= line. For the 10.1" panel the lane count depends
#    on the board: Pi 5 / CM5 use 4 lanes, Pi 3/4 use 2 (the overlay default).
# --------------------------------------------------------------------------
OVERLAY_LINE="dtoverlay=$PANEL"
MODEL="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || true)"
if [ "$PANEL" = "osoyoo-panel-dsi-10inch" ]; then
  case "$MODEL" in
    *"Raspberry Pi 5"*|*"Compute Module 5"*)
        OVERLAY_LINE="dtoverlay=$PANEL,4lane"
        note "Board is '$MODEL' -> using 4-lane variant" ;;
    *)  note "Board is '${MODEL:-unknown}' -> using 2-lane (default)" ;;
  esac
fi

# --------------------------------------------------------------------------
# 4. Ensure build tools + kernel headers are present
# --------------------------------------------------------------------------
DISTRO_ID="$( . /etc/os-release 2>/dev/null; echo "${ID:-}" )"
DISTRO_LIKE="$( . /etc/os-release 2>/dev/null; echo "${ID_LIKE:-}" )"
KREL="$(uname -r)"
KBUILD="/lib/modules/$KREL/build"
note "Running kernel: $KREL  (distro: ${DISTRO_ID:-unknown})"

# Guard against the "kernel swapped under us" trap: on a fresh Ubuntu image,
# unattended-upgrades often installs a NEWER kernel on first boot. If we build
# for the running kernel while a newer one is already installed, the next reboot
# switches to that newer kernel and our modules/overlay won't load. Reboot first.
NEWEST_KMOD="$(ls -1 /lib/modules 2>/dev/null | sort -V | tail -n1)"
if [ -n "$NEWEST_KMOD" ] && [ "$NEWEST_KMOD" != "$KREL" ]; then
  echo >&2
  note "WARNING: running '$KREL' but a newer kernel '$NEWEST_KMOD' is already installed."
  note "A reboot will switch to '$NEWEST_KMOD', and a build made for '$KREL' will NOT load."
  note "Recommended: 'sudo reboot' first, then re-run this script so it builds for '$NEWEST_KMOD'."
  if [ -t 0 ]; then
    read -r -p "Build for the running '$KREL' anyway? [y/N] " kans
    case "$kans" in [yY]|[yY][eE][sS]) : ;; *) die "Aborted — reboot, then re-run." ;; esac
  else
    note "Non-interactive shell — continuing, but expect to re-run after reboot."
  fi
fi

# apt wrapper: wait up to 10 min for the dpkg/apt lock instead of failing.
# A fresh Ubuntu image usually runs `unattended-upgrades` on first boot, which
# holds /var/lib/dpkg/lock-frontend; without the timeout, apt aborts immediately.
APT="sudo apt-get -o DPkg::Lock::Timeout=600"

APT_UPDATED=0
apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    note "apt-get update (waiting for any dpkg lock, e.g. unattended-upgrades)…"
    $APT update
    APT_UPDATED=1
  fi
}

# 4a. Compiler + dtc
NEED_PKGS=()
command -v make >/dev/null 2>&1 || NEED_PKGS+=("build-essential")
command -v gcc  >/dev/null 2>&1 || NEED_PKGS+=("build-essential")
command -v dtc  >/dev/null 2>&1 || NEED_PKGS+=("device-tree-compiler")
if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  if command -v apt-get >/dev/null 2>&1; then
    # de-duplicate
    UNIQ_PKGS="$(printf '%s\n' "${NEED_PKGS[@]}" | sort -u | tr '\n' ' ')"
    note "Installing build tools: $UNIQ_PKGS"
    apt_update_once
    $APT install -y $UNIQ_PKGS || die "Could not install: $UNIQ_PKGS"
  else
    die "Missing build tools (${NEED_PKGS[*]}) and no apt-get to install them. Install make/gcc/dtc manually."
  fi
fi

# 4b. Kernel headers for the RUNNING kernel
if [ ! -d "$KBUILD" ]; then
  note "Kernel headers for $KREL not found — installing…"
  if command -v apt-get >/dev/null 2>&1; then
    apt_update_once
    # The exact-version package name is identical on Ubuntu and Raspberry Pi OS.
    $APT install -y "linux-headers-$KREL" \
      || case "$DISTRO_ID:$DISTRO_LIKE" in
           ubuntu:*|*:*debian*)
             # Ubuntu-for-Pi meta packages (kernel flavour is -raspi)
             $APT install -y linux-headers-raspi linux-raspi-headers-"${KREL%-raspi}" ;;
           *)
             # Raspberry Pi OS fallbacks
             $APT install -y linux-headers-rpi-v8 linux-headers-rpi-2712 \
               || $APT install -y raspberrypi-kernel-headers ;;
         esac \
      || die "Could not install kernel headers for $KREL."
  else
    die "Kernel headers missing at $KBUILD and no apt-get available."
  fi
fi
[ -d "$KBUILD" ] || die "Kernel headers still missing at $KBUILD after install attempt."

if [ "$(id -u)" -eq 0 ]; then
  note "WARNING: running as root — building modules as root leaves root-owned files."
fi

# --------------------------------------------------------------------------
# 5. Build the modules against the detected kernel
#    KDIR=... overrides the Makefile's value so we always target THIS kernel.
# --------------------------------------------------------------------------
note "Building modules (make KDIR=$KBUILD)…"
make clean
make KDIR="$KBUILD"

for ko in osoyoo-dsi-panel.ko osoyoo-panel-regulator.ko; do
  [ -s "$SCRIPT_DIR/$ko" ] || die "build did not produce $ko"
done

# --------------------------------------------------------------------------
# 6. Install the modules
# --------------------------------------------------------------------------
note "Installing modules into /lib/modules/$KREL/ …"
sudo cp "$SCRIPT_DIR/osoyoo-dsi-panel.ko" "$SCRIPT_DIR/osoyoo-panel-regulator.ko" "/lib/modules/$KREL/"
sudo depmod "$KREL"

# --------------------------------------------------------------------------
# 7. Build the overlay straight into the boot overlays dir
#    (writing there with sudo avoids the root-owned-.dtbo "Permission denied"
#     trap; dtc prints harmless Warnings — only a FATAL ERROR is a failure.)
# --------------------------------------------------------------------------
note "Building overlay -> $OVERLAYS_DIR/$PANEL.dtbo …"
sudo dtc -@ -I dts -O dtb -o "$OVERLAYS_DIR/$PANEL.dtbo" "$DTS_FILE" 2>/tmp/osoyoo-dtc.log || {
  cat /tmp/osoyoo-dtc.log >&2
  die "dtc failed (see FATAL ERROR above)."
}
[ -s "$OVERLAYS_DIR/$PANEL.dtbo" ] || die "overlay .dtbo is missing or 0 bytes."
note "Overlay built OK (dtc warnings, if any, are harmless)."

# --------------------------------------------------------------------------
# 8. Set the dtoverlay= line in config.txt, idempotently
#    Remove any previous osoyoo overlay line first, then append the new one.
# --------------------------------------------------------------------------
note "Updating $CONFIG_TXT -> '$OVERLAY_LINE'"
sudo sed -i '/^[[:space:]]*dtoverlay=osoyoo/d' "$CONFIG_TXT"
echo "$OVERLAY_LINE" | sudo tee -a "$CONFIG_TXT" >/dev/null

# --------------------------------------------------------------------------
# 9. Done — summarise + offer reboot
# --------------------------------------------------------------------------
cat <<EOF

============================================================
 OSOYOO $LABEL panel driver installed.
   distro        : ${DISTRO_ID:-unknown}
   kernel        : $KREL
   modules       : /lib/modules/$KREL/{osoyoo-dsi-panel,osoyoo-panel-regulator}.ko
   overlay       : $OVERLAYS_DIR/$PANEL.dtbo
   config.txt    : $OVERLAY_LINE
============================================================

A reboot is required. After it comes back, verify with:
   cat /sys/class/backlight/*/display_name      # should print: DSI-1

NOTE (Ubuntu A/B layout): a later kernel upgrade (apt) installs a new kernel and
swaps the current/ <-> new/ boot slots, which drops these out-of-tree modules and
the overlay. If the panel goes dark after a kernel update, just re-run this script.
EOF

if [ -t 0 ]; then
  read -r -p "Reboot now? [y/N] " ans
  case "$ans" in
    [yY]|[yY][eE][sS]) note "Rebooting…"; sudo reboot ;;
    *) note "Not rebooting. Run 'sudo reboot' when ready." ;;
  esac
else
  note "Non-interactive shell — not rebooting. Run 'sudo reboot' when ready."
fi
