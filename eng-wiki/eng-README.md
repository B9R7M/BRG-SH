**[PT-BR](https://github.com/B9R7M/BRG-SH/blob/main/README.md)** | **English**

---

# BRG-SH (build_rom_generic.sh)

It is an interactive `bash` script for **compiling AOSP Custom ROMs** (LineageOS, AxionOS,
crDroid, PixelOS, Evolution X, etc.) on Ubuntu/Debian distributions.

---

## Read before you start!

This script **does not work automatically** for any device.
You will need to **manually configure** the variables at the top of the file
and **find the correct repositories** for **YOUR device** (if available).

### Recommended sources

- **XDA Developers** > [xdaforums.com](https://xdaforums.com)
  - Search for your device model (Development threads usually list all the necessary repositories).

- **LineageOS Wiki** > [wiki.lineageos.org/devices](https://wiki.lineageos.org/devices)
  - Official list of supported devices with direct links to device trees. (Even if you don't want LineageOS, the trees are a base for other ROMs).

- **GitHub** > [github.com](https://github.com)
  - Search for:
    - `android_device_<manufacturer>_<codename>` > **device tree**
    - `android_kernel_<manufacturer>_<chipset>` > **kernel source**
    - `proprietary_vendor_<manufacturer>_<codename>` > **vendor blobs**
  
- **Relevant organizations:** `LineageOS`, `TheMuppets`, `AOSPA`, `crdroidandroid`, `PixelOS`, `/e/OS`

  - **Telegram / Matrix** > ROM development groups. Many projects have groups where maintainers and users share repositories, patches, and support. Check the ROM's website/GitHub for community links.

### Essential terms

This script also **does not provide all the necessary knowledge** to compile any ROM without prior in-depth study. It is essential to have previous technical knowledge about the process to proceed successfully.

Click **[HERE](https://drive.google.com/drive/folders/1zojYA3EaUBtd_drbRoTjIgxNxFVzFGUI)** to access the basic material needed to follow the guide.

> [!NOTE]  
> This is a spreadsheet hosted on Google Drive. Use Google Sheets or any software compatible with Excel files `(.xlsx)` to view it.

---

## Initial Setup

Open the `build_rom_generic.sh` file and edit **Section 1 — Settings**:

```bash
# Device codename (e.g., pstar, tundra, mh2lm)
DEVICE="your_codename_here"

# Manufacturer (e.g., motorola, oneplus, google, xiaomi)
MANUFACTURER="manufacturer_here"

# ROM branch (e.g., lineage-23.1, fourteen, udc)
BRANCH_ROM="branch-name-here"

# Device tree branch (may be different)
BRANCH_DEVICE="device-tree-branch-name"

# ROM manifest URL
ROM_MANIFEST_URL="https://github.com/YourROM/android.git"

# URLs of your device's repositories
DEVICE_TREE_URL="https://github.com/..."
KERNEL_REPO_URL="https://github.com/..."
VENDOR_REPO_URL="https://github.com/..."

# Number of threads (see Hardware section below)
JOBS=4

# Your git details (required)
GIT_EMAIL="you@example.com"
GIT_NAME="Your Name"
```

---

## Minimum Hardware Requirements

| Component | Recommended Minimum | Notes                                              |
|-----------|---------------------|----------------------------------------------------|
| CPU       | 4 cores             | The more, the better!                              |
| RAM       | 16 GB               | Configure swap (see below)                         |
| Swap      | 16 GB               | Essential and useful with low RAM                  |
| Storage   | 400GB – 1TB         | SSD recommended                                    |
| OS        | Ubuntu (e.g., 24.04)| Also works on Linux Mint, Debian, Pop!_OS          |

### Configure Swap

```bash
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

To make it permanent, add to `/etc/fstab`:
```
/swapfile none swap sw 0 0
```

> [!TIP]
> Swap uses internal storage as a swap area for RAM. Therefore, the faster the SSD, the better. Whenever possible, it is recommended to use NVMe SSDs, which offer superior transfer rates compared to SATA models.

> [!CAUTION]
> Configuring swap space larger than the amount of available RAM can accelerate SSD wear, reducing its lifespan. Although it is a necessary practice to avoid OOM Killer activation, it is advisable to constantly monitor the SSD's temperature and health status during intensive workloads.

### Configure JOBS according to your hardware

| CPU          | RAM     | Recommended JOBS |
|--------------|---------|------------------|
| 4 cores      | 16 GB   | 2 to 4           |
| 8 cores      | 32 GB   | 6 to 8           |
| 12+ cores    | 48 GB+  | 10 to 12         |

> [!WARNING]
> The JOBS limit is your number of CPU cores; if you exceed the limit, the system may freeze due to OOM/OOM Killer (Out Of Memory/Killer).

---

## How to Use

```bash
chmod +x build_rom_generic.sh
./build_rom_generic.sh
```

The script will display an interactive menu:

```
── Setup (first time) ───────────────────────────────────
[0] Everything from scratch (all steps in sequence)
[1] Initial system checks
[2] Install dependencies"
[3] Configure environment (repo, git, ccache)
[4] Download ROM source
[5] Clone device trees (device / kernel / vendor)
[6] Apply ROM patches/configurations
── Build ─────────────────────────────────────────────────
[7] Compile (asks for variant first)
[v] Change build variant
── Backup & Sync ─────────────────────────────────────────
[b] Backup custom configurations
[r] Restore backup (choose which)
[s] Safe sync (backup → sync → auto-restore)
── Diagnostics ───────────────────────────────────────────
[d] Check repository branches"
[q] Exit
```

### First time? Use option `[0]`

It runs all steps in sequence, asking for confirmation at each one.

---

## Detailed steps

### `[1]` Initial checks
Checks Linux distribution, disk space, and available memory.

### `[2]` Install dependencies
Installs all necessary packages via `apt`. Requires `sudo`.

> [!IMPORTANT]
> Using `sudo` in automation scripts can cause workflow failures. To avoid this issue, you must configure `visudo` to allow execution without password prompting before running the script.

> [!WARNING]
> Disabling the `sudo` password reduces system security.
> Any malicious script or unauthorized user can execute commands as root without any barrier.
> **Use only in controlled environments** (local VM, container, isolated build machine).

- **How to configure**

  Edit the sudoers file **always via `visudo`** — it validates syntax before saving, preventing system lockouts.

  ```bash
  sudo visudo
  ```

  Add to the end of the file:

  ```
  # No password for a specific user
  youruser ALL=(ALL) NOPASSWD: ALL

  # Or for an entire group (e.g., sudo/wheel)
  %sudo ALL=(ALL) NOPASSWD: ALL
  ```

  Save and exit. The change takes effect immediately.

- **Using a separate file (recommended)**

  ```bash
  echo "youruser ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/nopasswd
  sudo chmod 440 /etc/sudoers.d/nopasswd
  ```

- **Revert (if you feel the need)**

  Simply remove the added line via `visudo` or delete the created file:

  ```bash
  sudo rm /etc/sudoers.d/nopasswd
  ```

> [!TIP]
> > In CI/CD pipelines, prefer creating a dedicated user with `NOPASSWD` restricted to specific commands, rather than allowing everything with `ALL`.

### `[3]` Configure environment
Configures `repo`, `git`, `ccache`, and environment variables in `.bashrc`/`.profile`.

> [!TIP]
> Some Linux distributions require prior configuration of `ccache` before starting the build, either due to permission restrictions or system limitations.

- **Installation**

  ```bash
  # Debian/Ubuntu
  sudo apt install ccache

  # Arch
  sudo pacman -S ccache

  # Fedora/RHEL
  sudo dnf install ccache
  ```

- **Basic configuration**

  Set the directory and maximum cache size:

  ```bash
  # Default directory: ~/.cache/ccache (can be changed)
  export CCACHE_DIR=~/.cache/ccache

  # Recommended maximum size for AOSP builds: 50–100 GB
  ccache -M 50G
  ```

  Add to `~/.bashrc` or `~/.zshrc` to persist:

  ```bash
  export USE_CCACHE=1
  export CCACHE_DIR=~/.cache/ccache
  ```

- **Common issues**

  | Problem                   | Cause                                | Solution                                              |
  |---------------------------|--------------------------------------|-------------------------------------------------------|
  | `permission denied`       | Directory lacks write permission     | `sudo chown -R $USER ~/.cache/ccache`                 |
  | `ccache: not found`       | Not installed or not in PATH         | Install and add `/usr/lib/ccache` to `$PATH`          |
  | Cache not being used      | `USE_CCACHE` variable not exported   | Add to `.bashrc` and run `source ~/.bashrc`           |

- **Check if it's working**

  ```bash
  ccache -s
  ```

  After a clean build, the `cache hit` fields should increase in subsequent runs.

---

### `[4]` Download ROM source
Initializes `repo` and syncs the source. May take **hours** depending on your internet connection (150–200GB download on average for more recent builds).

> [!TIP]
> If the sync hangs or drops midway, just run it again; it resumes from where it stopped.

### `[5]` Clone device trees
Clones device tree, kernel, and vendor blobs. **You need to configure the correct URLs.**

### `[6]` Patches
Customizable step. By default, it does nothing; edit the `step5_patches()` function to add ROM-specific patches.

### `[7]` Compile
Sets the target and starts the compilation. The log is saved in `$BUILD_DIR/build_*.log`.

---

## Backup system

The script includes a backup system to **preserve manual modifications** that would be overwritten by a `repo sync`.

### How it works

1. `[b]` — Backs up files listed in `BACKUP_FILES`
2. `[r]` — Restores a previous backup (you choose which)
3. `[s]` — **Safe sync**: backup → sync → auto-restore

### Configure files for backup

Edit the `BACKUP_FILES` variable in the script:

```bash
BACKUP_FILES=(
    "device/manufacturer/codename/device.mk"
    "device/manufacturer/codename/BoardConfig.mk"
    # Add other files you manually edit
)
```

Backups are stored in `~/rom_backup/` with a timestamp, and a symlink `latest` always points to the most recent one.

---

## Troubleshooting

### Incorrect branches
One of the most common issues. Use option `[d]` to check if all repositories are on the correct branch.

To fix manually:
```bash
cd $BUILD_DIR/device/manufacturer/codename
git fetch origin correct-branch
git checkout correct-branch
```

### Common `mkdir` errors

| Message                          | Probable cause                              | Solution                                     |
|----------------------------------|---------------------------------------------|----------------------------------------------|
| `Permission denied`              | No permission on parent directory (root)    | `sudo chown $USER:$USER <directory>`         |
| `Not a directory`                | A file with the same name exists            | `rm <name>` and create the directory again   |
| `No such file or directory`      | Parent directory does not exist             | `mkdir -p <full path>`                       |
| `mkdir: cannot create directory` | Invalid path or device full                 | Check disk space: `df -h`                    |

> [!TIP]
> The script uses `mkdir -p` in all directory creations. If it still fails,
> create the directories manually and try again.

### Common compilation errors

| Error                              | Probable cause                     | Solution                                              |
|------------------------------------|------------------------------------|-------------------------------------------------------|
| `soong bootstrap failed`           | Wrong branch in repos              | Use `[d]` to check and fix branches                  |
| `module not found: <module>`       | Dependency not cloned              | Clone the missing repository                          |
| `Out of memory` / OOM killer       | Insufficient RAM                   | Add swap, reduce JOBS                                 |
| `ninja: build stopped`             | Generic compilation error          | Check the full log                                    |
| `repository not found`             | Incorrect URL                      | Verify the URL on GitHub / XDA                        |
| `breakfast: command not found`     | envsetup.sh not loaded             | Run `source build/envsetup.sh` manually               |

### Check the compilation log

```bash
# View the last lines of the log
tail -100 ~/android/rom/build_userdebug_*.log

# Search for errors
grep -i "error\|failed\|FAILED" ~/android/rom/build_userdebug_*.log | tail -30
```

---

## Signing keys

On the first compilation, the script automatically generates signing keys in `$BUILD_DIR/certs/`.

> [!TIP]
> If an error occurs during key generation, such as an attempt to create a non-existent directory, you may need to create that directory manually. To identify the correct location, it is recommended to analyze the script present in the ROM source, which in most cases is found in `build/envsetup.sh`.

> [!CAUTION]
> **Keep these keys safe!** If you lose them, future builds will not be compatible with previous ones, and you will need to perform a full **wipe** to install a new build.

Backup the keys:
```bash
cp -r ~/android/rom/certs ~/my-secure-folder/
```

---

## Build variants

| Variant      | Use                          | ADB Root | Description                            |
|--------------|------------------------------|----------|----------------------------------------|
| `userdebug`  | Development / testing        | Yes      | Recommended for testing and debugging  |
| `user`       | Daily use / distribution     | No       | More restricted, closer to production  |
| `eng`        | Engineering                  | Yes      | Very permissive, not recommended       |

Some ROMs use their own variants (e.g., `gms_core`, `gms_pico`, `vanilla`).
Consult your ROM's documentation.

---

## Basic directory structure

```
~/android/rom/ ← ROM source (BUILD_DIR)
├── .repo/ ← repo configuration
├── build/ ← Android build system
├── device/
│   └── manufacturer/
│       └── codename/ ← Device tree
├── kernel/
│   └── manufacturer/
│       └── chipset/ ← Kernel source
├── vendor/
│   └── manufacturer/
│       └── codename/ ← Vendor blobs
├── certs/ ← Signing keys (DO NOT delete!)
├── out/target/product/
│   └── codename/ ← Generated files (.zip, .img)
└── build_*.log ← Compilation logs

~/rom_backup/ ← Backups of customizations (BACKUP_DIR)
├── 20250101_120000/ ← Backup with timestamp
├── 20250115_090000/
└── latest -> ... ← Symlink to the most recent
```

---

## Adaptation for different ROMs

The script is meant to be adapted. Main points to customize:

1. **Variables at the top** — URLs, branches, device, manufacturer
2. **`BACKUP_FILES`** — Files you manually edit
3. **`step5_patches()`** — ROM-specific patches (e.g., flags in device.mk)
4. **`step4_device_trees()`** — Add extra repos if the ROM requires them
5. **`step6_build()`** — Adapt the build command according to the ROM

---

## License

**[MIT](https://github.com/B9R7M/ACL-SH/blob/main/LICENSE)** — Do whatever you want, but without warranties. Use at your own risk.

---

### Sources:

- **[AOSP](https://source.android.com)**
- **[LineageOS for pstar](https://wiki.lineageos.org/devices/pstar/build)**
- **[VegaData](https://youtu.be/vX8t9l8gnT0)** (**[VegaBobo - Github](https://github.com/VegaBobo)**)
- **[AxionOS Manifest](https://github.com/AxionAOSP/android)**
- **[XDA Forums](https://xdaforums.com)**
- **[TheMuppets](https://github.com/TheMuppets)**

---
