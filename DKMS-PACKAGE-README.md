# OSOYOO DSI Panel DKMS Package

This directory contains the DKMS packaging for the OSOYOO DSI panel driver, which enables automatic driver rebuilds when the kernel is updated.

## What is DKMS?

DKMS (Dynamic Kernel Module Support) automatically rebuilds kernel modules when you upgrade your kernel. This means users don't have to manually rebuild the driver after each `sudo apt upgrade`.

## Building the Package

### Prerequisites

Install the required build tools on a Raspberry Pi or Debian/Ubuntu system:

```bash
sudo apt-get install build-essential debhelper dkms device-tree-compiler
```

### Build Steps

1. Navigate to this directory
2. Run the build script:

```bash
./build-deb.sh
```

3. The package will be created in the parent directory:
   - `../osoyoo-dsi-panel-dkms_1.0-1_all.deb`

### Testing Locally

Install the package on your Raspberry Pi:

```bash
sudo dpkg -i ../osoyoo-dsi-panel-dkms_1.0-1_all.deb
sudo apt-get install -f  # Install any missing dependencies
```

## Distribution Options

### Option 1: Direct Distribution

Share the `.deb` file directly. Users install with:

```bash
sudo dpkg -i osoyoo-dsi-panel-dkms_1.0-1_all.deb
sudo apt-get install -f
```

### Option 2: Host on GitHub Releases

1. Create a release on your GitHub repository
2. Upload the `.deb` file as a release asset
3. Users download and install:

```bash
wget https://github.com/osoyoo/osoyoo-dsi-panel/releases/download/v1.0/osoyoo-dsi-panel-dkms_1.0-1_all.deb
sudo dpkg -i osoyoo-dsi-panel-dkms_1.0-1_all.deb
sudo apt-get install -f
```

### Option 3: Create Your Own APT Repository

For automatic updates via `apt upgrade`, create a personal APT repository:

#### Using GitHub Pages + `apt-get`

1. **Install required tools:**
   ```bash
   sudo apt-get install dpkg-dev gnupg
   ```

2. **Create repository structure:**
   ```bash
   mkdir -p apt-repo/pool/main
   cp osoyoo-dsi-panel-dkms_1.0-1_all.deb apt-repo/pool/main/
   cd apt-repo
   ```

3. **Generate Packages file:**
   ```bash
   dpkg-scanpackages pool/ /dev/null | gzip -9c > Packages.gz
   dpkg-scanpackages pool/ /dev/null > Packages
   ```

4. **Create Release file:**
   ```bash
   cat > Release << EOF
   Origin: OSOYOO DSI Panel Repository
   Label: OSOYOO
   Suite: stable
   Codename: stable
   Architectures: all
   Components: main
   Description: OSOYOO DSI Panel Driver Repository
   EOF
   ```

5. **Sign the repository (optional but recommended):**
   ```bash
   gpg --gen-key  # Create a GPG key if you don't have one
   gpg --armor --export support@osoyoo.info > public.key
   gpg --clearsign -o InRelease Release
   ```

6. **Host on GitHub Pages:**
   - Push the `apt-repo` directory to a GitHub repository
   - Enable GitHub Pages in repository settings
   - Users add your repository:

   ```bash
   # Add repository
   echo "deb [trusted=yes] https://osoyoo.github.io/osoyoo-dsi-panel/ ./" | \
       sudo tee /etc/apt/sources.list.d/osoyoo.list

   # Or with GPG signature verification:
   wget -qO - https://osoyoo.github.io/osoyoo-dsi-panel/public.key | sudo apt-key add -
   echo "deb https://osoyoo.github.io/osoyoo-dsi-panel/ ./" | \
       sudo tee /etc/apt/sources.list.d/osoyoo.list

   # Install
   sudo apt update
   sudo apt install osoyoo-dsi-panel-dkms
   ```

#### Using packagecloud.io (Easiest)

1. Create free account at https://packagecloud.io
2. Upload your `.deb` file
3. They provide installation instructions automatically

### Option 4: Submit to Raspberry Pi Repository

For official inclusion in Raspberry Pi OS:

1. **Fork and contribute to Raspberry Pi kernel:**
   - Fork: https://github.com/raspberrypi/linux
   - Add your driver to `drivers/gpu/drm/panel/`
   - Submit a pull request

2. **Benefits:**
   - Included in all Raspberry Pi OS installations
   - Automatic kernel updates include your driver
   - No separate package needed

## How DKMS Works for Users

Once installed, the package:

1. **On installation:**
   - Registers the driver source with DKMS
   - Compiles modules for current kernel
   - Installs modules to `/lib/modules/$(uname -r)/`
   - Compiles and installs device tree overlays

2. **On kernel update:**
   - DKMS automatically detects new kernel
   - Rebuilds modules for new kernel
   - Installs modules for new kernel
   - User doesn't need to do anything!

3. **On package removal:**
   - Removes modules from all kernels
   - Removes device tree overlays (on purge)
   - Cleans up DKMS registration

## User Instructions

After installation, users need to:

1. Edit `/boot/config.txt` or `/boot/firmware/config.txt`
2. Add one of these lines:
   - For 7" panel: `dtoverlay=osoyoo-panel-dsi-7inch`
   - For 10.1" panel: `dtoverlay=osoyoo-panel-dsi-10inch`
   - For 10.1" 4-lane: `dtoverlay=osoyoo-panel-dsi-10inch,4lane`
3. Reboot

## Updating Package Metadata

Before building, update these files:

1. **debian/control** - Update maintainer name and email
2. **debian/changelog** - Add new version entries
3. **debian/copyright** - Add your copyright information
4. **dkms.conf** - Update version if changed

## Version Updates

When releasing a new version:

1. Update version in:
   - `debian/changelog` (add new entry at top)
   - `dkms.conf` (PACKAGE_VERSION)
   - `debian/postinst` (PACKAGE_VERSION)
   - `debian/prerm` (PACKAGE_VERSION)
   - `debian/postrm` (PACKAGE_VERSION)

2. Rebuild the package
3. If using APT repository, regenerate Packages file

## Troubleshooting

### Check DKMS status
```bash
dkms status osoyoo-dsi-panel
```

### Rebuild manually
```bash
sudo dkms build -m osoyoo-dsi-panel -v 1.0
sudo dkms install -m osoyoo-dsi-panel -v 1.0
```

### View installed modules
```bash
lsmod | grep osoyoo
modinfo osoyoo-panel-dsi
```

### Check device tree overlays
```bash
ls -l /boot/overlays/osoyoo*
# or
ls -l /boot/firmware/overlays/osoyoo*
```

## Files Created by This Package

- `/usr/src/osoyoo-dsi-panel-1.0/` - Source files
- `/lib/modules/$(uname -r)/updates/dkms/osoyoo-panel-*.ko` - Compiled modules
- `/boot/overlays/osoyoo-panel-dsi-*.dtbo` - Device tree overlays
- `/var/lib/dkms/osoyoo-dsi-panel/` - DKMS metadata

## Support

For issues or questions:
- GitHub Issues: https://github.com/osoyoo/osoyoo-dsi-panel/issues
- Email: support@osoyoo.info
- Documentation: https://github.com/osoyoo/osoyoo-dsi-panel
