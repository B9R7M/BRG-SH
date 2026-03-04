#!/bin/bash
# =============================================================================
#  BRG-SH
#  Version: 1.0
# =============================================================================

set -E  # Propaga ERR trap para subshells

# Captura Ctrl+C e volta ao menu em vez de encerrar o script
trap 'echo ""; warn "Interrupted. Returning to main menu..."; main' INT

# =============================================================================
#  SECTION 1: SETTINGS — EDIT HERE BEFORE RUNNING
# =============================================================================

# ── Device identification ────────────────────────────────────────────────────
# Device codename (e.g.: "pstar", "tundra", "sunfish", "rosy")
# TIP: The codename is usually found in the "device/<manufacturer>/<codename>" folder
# in the device tree, and can be found on XDA or the LineageOS Wiki.
DEVICE="your_codename_here"

# Device manufacturer (e.g.: "motorola", "oneplus", "google", "xiaomi")
MANUFACTURER="manufacturer_here"

# ── ROM and device tree branches ────────────────────────────────────────────
# ROM branch you want to build
# TIP: Check the ROM repository on GitHub for available branches.
# Examples: "lineage-21", "lineage-22.2", "lineage-23.1", "fourteen", "udc, etc"
BRANCH_ROM="branch-name-here"

# Device tree branch (may differ from the ROM branch)
# TIP: Check the device tree repository for available branches.
#      Usually follows the same pattern as the ROM if there is official support (e.g.: "lineage-23.2"), but there are exceptions
BRANCH_DEVICE="device-tree-branch-name"

# ── Repository URLs ──────────────────────────────────────────────────────────
# Manifest = main repository of the ROM
# TIP: Usually on the ROM's GitHub. Look for a repo called "android"
#      or "manifest" in the ROM's organization (e.g.: github.com/AxionAOSP/android)
ROM_MANIFEST_URL="https://github.com/YourROM/android.git"

# Your device's device tree
# TIP: Search on GitHub: android_device_<manufacturer>_<codename>
#      Example: android_device_motorola_pstar
DEVICE_TREE_URL="https://github.com/LineageOS/android_device_${MANUFACTURER}_${DEVICE}.git"

# Your device's kernel source
# TIP: Search on GitHub: android_kernel_<manufacturer>_<chipset>
#      The chipset can be found in the device specs (e.g.: sm8250, mt6768)
#      WARNING: Not every ROM recompiles the kernel. Check your ROM's documentation (if available)
KERNEL_REPO_URL="https://github.com/LineageOS/android_kernel_${MANUFACTURER}_chipset.git"

# Device vendor blobs
# TIP: Search on GitHub: proprietary_vendor_<manufacturer>_<codename>
#      Common sources: TheMuppets (https://github.com/TheMuppets)
VENDOR_REPO_URL="https://github.com/TheMuppets/proprietary_vendor_${MANUFACTURER}_${DEVICE}.git"

# ── Directories ──────────────────────────────────────────────────────────────
# Directory where the ROM source will be downloaded
# IMPORTANT: Requires a lot of space (~400-600GB depending on the ROM)
BUILD_DIR="$HOME/android/rom"

# Directory for the "repo" binary
# TIP: If you encounter a "repo: command not found" error, check if this
#      directory is in your PATH. Add to ~/.bashrc: export PATH="$HOME/bin:$PATH"
BIN_DIR="$HOME/bin"

# ccache directory (compilation cache)
# TIP: Place on a fast disk (SSD). Do not change if you're unsure.
CCACHE_DIR="$HOME/.ccache"

# Backup directory for your customizations
# WARNING: If you encounter an error creating this directory (e.g.: "Permission denied"),
#          create it manually: mkdir -p ~/rom_backup
BACKUP_DIR="$HOME/rom_backup"

# ── Performance ──────────────────────────────────────────────────────────────
# ccache size. Recommended default: 50G (50 GB)
# With more space, subsequent builds become MUCH faster.
CCACHE_SIZE="50G"

# Number of compilation threads
# GENERAL RULE: number of CPU cores (e.g.: 8 cores → JOBS=8)
# IF YOU HAVE LOW RAM (<16GB): use half the cores (e.g.: 8 cores → JOBS=4)
# WITH LESS THAN 8GB RAM: DON'T EVEN TRY TO BUILD!
# WARNING: Setting too high may freeze the system due to out of memory!
JOBS=4

# ── Git ──────────────────────────────────────────────────────────────────────
# Your email and name for git (required for repo sync to work)
GIT_EMAIL="you@example.com"
GIT_NAME="Your Name"

# ── Build variant ────────────────────────────────────────────────────────────
# Many ROMs have variants. Adjust according to your ROM:
#   "userdebug" → For development/debugging (most common)
#   "user"      → For daily use (more restricted, no ADB root)
#   "eng"       → Engineering (very permissive, not recommended for daily use)
# SOME ROMs use custom names (e.g.: "gms_core", "vanilla")
BUILD_TYPE="userdebug"

# =============================================================================
#  SECTION 2: BACKUP FILES
#  List here any files you manually edit in the source.
#  Paths relative to BUILD_DIR.
# =============================================================================

# Examples of common files that need backup after manual modification:
BACKUP_FILES=(
    "device/${MANUFACTURER}/${DEVICE}/device.mk"
    "device/${MANUFACTURER}/${DEVICE}/BoardConfig.mk"
    "device/${MANUFACTURER}/${DEVICE}/BoardConfigVendor.mk"
    # Add other files you modify:
    # "device/<manufacturer>/<device>/sepolicy/genfs_contexts"
    # "device/<manufacturer>/<device>/rootdir/etc/init.<codename>.rc"
)

# =============================================================================
#  SECTION 3: COLORS AND OUTPUT FUNCTIONS
#  No need to edit anything below this line for basic usage.
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'  # No Color (reset)

# Formatted output functions:
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; return 1; }
tip()     { echo -e "${MAGENTA}[DICA]${NC} $1"; }

# Interactive confirmation function (y/N response)
confirm() {
    read -rp "$(echo -e "${YELLOW}$1 [y/N]: ${NC}")" resp
    [[ "$resp" =~ ^[yY]$ ]] || { info "Skipping step."; return 1; }
    return 0
}

# Pause and wait for Enter before returning to the menu
pause_menu() {
    echo ""
    read -rp "$(echo -e "${CYAN}Press Enter to return to the menu...${NC}")"
}

# =============================================================================
#  SECTION 4: SYSTEM CHECKS
# =============================================================================

# Checks available disk space at a given path
# Usage: check_space <required_gb> <path>
check_space() {
    local required_gb=$1
    local path=$2
    local available_gb

    # Create directory if it does not exist, to be able to check
    mkdir -p "$path" 2>/dev/null || true

    available_gb=$(df -BG "$path" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')

    if [ -z "$available_gb" ] || [ "$available_gb" -lt "$required_gb" ]; then
        error "Insufficient space at $path. Required: ${required_gb}GB | Available: ${available_gb:-?}GB"
    fi
    success "Space at $path: ${available_gb}GB available (minimum: ${required_gb}GB)"
}

# Checks available RAM and swap
# TIP: Building Android requires a lot of memory. Recommended minimum: 16GB RAM+Swap
check_ram_and_swap() {
    local total_ram_mb
    local total_swap_mb
    total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    total_swap_mb=$(free -m | awk '/^Swap:/{print $2}')
    local total_mb=$(( total_ram_mb + total_swap_mb ))

    info "RAM: ${total_ram_mb}MB | Swap: ${total_swap_mb}MB | Total: ${total_mb}MB"

    if [ "$total_swap_mb" -lt 8192 ]; then
        warn "Swap smaller than 8GB detected!"
        warn "With low swap, the build MAY hang or kill processes (OOM Killer)."
        warn "Commands to create swap (run before building):"
        echo ""
        echo "  sudo fallocate -l 16G /swapfile"
        echo "  sudo chmod 600 /swapfile"
        echo "  sudo mkswap /swapfile"
        echo "  sudo swapon /swapfile"
        echo ""
        warn "To make it permanent, add to /etc/fstab:"
        echo "  /swapfile none swap sw 0 0"
        echo ""
        tip "If your HDD/SSD is slow, file-based swap may be slower than RAM."
        tip "In that case, consider zram: sudo apt install zram-config"
        echo ""
        confirm "Continue without adequate swap? (NOT recommended)" || return 1
    else
        success "Adequate swap detected."
    fi
}

# =============================================================================
#  SECTION 5: BUILD VARIANT SELECTION
#  Adjust according to the variants supported by your ROM.
# =============================================================================

select_variant() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             Select the Build Variant                 ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}   [1] userdebug  — Development          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   [2] user       — Daily use            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   [3] eng        — Engineering          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   NOTE: Some ROMs use custom names      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   e.g. gms_core, gms_pico, vanilla      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Current variant: ${GREEN}${BUILD_TYPE}${NC}"
    echo ""
    read -rp "$(echo -e "${YELLOW}Choose [1/2/3] or press Enter to keep current: ${NC}")" var_opt

    case "$var_opt" in
        1) BUILD_TYPE="userdebug"; success "Variant: userdebug" ;;
        2) BUILD_TYPE="user";      success "Variant: user" ;;
        3) BUILD_TYPE="eng";       warn "Variant: eng (not recommended for daily use)" ;;
        "") info "Keeping variant: $BUILD_TYPE" ;;
        *) warn "Invalid option. Keeping: $BUILD_TYPE" ;;
    esac
}

# =============================================================================
#  SECTION 6: BACKUP AND RESTORE
#  Saves and restores manually edited files (useful after repo sync)
# =============================================================================

step_backup_save() {
    info "══════════════════════════════════════════════════"
    info "   BACKUP: Saving custom configurations"
    info "══════════════════════════════════════════════════"

    # Create backup directory
    # TIP: If you get a "Permission denied" or "No such file or directory" error,
    #      create it manually: mkdir -p ~/rom_backup
    mkdir -p "$BACKUP_DIR" || error "Could not create $BACKUP_DIR. Create manually: mkdir -p $BACKUP_DIR"

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_slot="$BACKUP_DIR/$timestamp"

    mkdir -p "$backup_slot"

    local saved=0
    local skipped=0

    for rel_path in "${BACKUP_FILES[@]}"; do
        local full_path="$BUILD_DIR/$rel_path"
        if [ -f "$full_path" ]; then
            local dest_dir="$backup_slot/$(dirname "$rel_path")"
            # TIP: If mkdir fails here, the path may contain special characters.
            #      Check the names in BACKUP_FILES above.
            mkdir -p "$dest_dir"
            cp "$full_path" "$dest_dir/"
            info "  Saved: $rel_path"
            ((saved++))
        else
            warn "  Not found (skipping): $rel_path"
            ((skipped++))
        fi
    done

    # Also saves the build variant and general settings
    {
        echo "BUILD_TYPE=$BUILD_TYPE"
        echo "BACKUP_DATE=$timestamp"
        echo "DEVICE=$DEVICE"
        echo "BRANCH_ROM=$BRANCH_ROM"
    } > "$backup_slot/build_config.env"

    # Creates "latest" symlink pointing to the most recent backup
    ln -sfn "$backup_slot" "$BACKUP_DIR/latest"

    echo ""
    success "Backup saved to: $backup_slot"
    success "Files saved: $saved | Not found: $skipped"
    info "Quick access: $BACKUP_DIR/latest"

    echo ""
    info "Available backups (last 10):"
    ls -1 "$BACKUP_DIR" | grep -v "^latest$" | sort -r | head -10 | \
        while read -r b; do echo "  • $b"; done
}

step_backup_restore() {
    info "══════════════════════════════════════════════════"
    info "     Restoring custom configurations"
    info "══════════════════════════════════════════════════"

    if [ ! -d "$BACKUP_DIR" ]; then
        error "No backup found at $BACKUP_DIR. Make a backup first (option [b])."
    fi

    # List available backups (excluding the 'latest' symlink)
    local backups=()
    while IFS= read -r b; do
        [[ "$b" != "latest" ]] && backups+=("$b")
    done < <(ls -1 "$BACKUP_DIR" | grep -v "^latest$" | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        error "No backup found at $BACKUP_DIR."
    fi

    echo ""
    echo "  Available backups (most recent first):"
    echo ""

    local latest_target
    latest_target=$(readlink "$BACKUP_DIR/latest" 2>/dev/null | xargs basename 2>/dev/null || echo "")

    for i in "${!backups[@]}"; do
        local b="${backups[$i]}"
        local tag=""
        [[ "$b" == "$latest_target" ]] && tag=" ${GREEN}← most recent${NC}"
        printf "  [%d] %s%b\n" "$((i+1))" "$b" "$tag"
    done

    echo ""
    read -rp "$(echo -e "${YELLOW}Which to restore? [1-${#backups[@]}] or Enter for the most recent: ${NC}")" restore_opt

    local chosen_backup
    if [ -z "$restore_opt" ]; then
        chosen_backup="$BACKUP_DIR/${backups[0]}"
        info "Using most recent backup: ${backups[0]}"
    elif [[ "$restore_opt" =~ ^[0-9]+$ ]] && \
         [ "$restore_opt" -ge 1 ] && \
         [ "$restore_opt" -le "${#backups[@]}" ]; then
        chosen_backup="$BACKUP_DIR/${backups[$((restore_opt-1))]}"
        info "Using backup: ${backups[$((restore_opt-1))]}"
    else
        error "Invalid option."
    fi

    echo ""
    confirm "Confirm restore of $(basename "$chosen_backup")?" || return 0

    local restored=0
    local not_in_backup=0

    for rel_path in "${BACKUP_FILES[@]}"; do
        local src="$chosen_backup/$rel_path"
        local dest="$BUILD_DIR/$rel_path"

        if [ -f "$src" ]; then
            # Preserves current file with .before_restore extension (safety net)
            [ -f "$dest" ] && cp "$dest" "${dest}.before_restore"

            # TIP: If mkdir fails during restore, the destination path may not exist.
            #      This can happen if the device tree has not been cloned yet.
            #      Clone the device tree first (option [5]) and try again.
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            info "  Restored: $rel_path"
            ((restored++))
        else
            warn "  Not in backup (skipping): $rel_path"
            ((not_in_backup++))
        fi
    done

    # Restores build variant if available in the backup
    local config_env="$chosen_backup/build_config.env"
    if [ -f "$config_env" ]; then
        local saved_variant
        saved_variant=$(grep "^BUILD_TYPE=" "$config_env" | cut -d'=' -f2)
        if [ -n "$saved_variant" ]; then
            BUILD_TYPE="$saved_variant"
            info "  Build variant restored: $BUILD_TYPE"
        fi
    fi

    echo ""
    success "Restore complete! Restored: $restored | Not found: $not_in_backup"
    warn "Original files preserved with .before_restore extension"
}

# =============================================================================
#  SECTION 7: SAFE SYNC
#  Performs backup → source sync → auto-restore
# =============================================================================

step_sync_safe() {
    info "══════════════════════════════════════════════════"
    info "       Backup → Sync → Auto-restore"
    info "══════════════════════════════════════════════════"
    warn "This option backs up your customizations BEFORE the sync and"
    warn "restores them automatically AFTER. Ideal for keeping patches."
    echo ""
    confirm "Run safe sync now?" || return 0

    info "Step 1/3: Backing up configurations..."
    step_backup_save

    info "Step 2/3: Syncing source..."
    cd "$BUILD_DIR"
    # TIP: "-j4" = 4 parallel downloads. Increase if you have a good connection.
    #       "-c" = current branch only (saves space and time)
    #       "--no-tags" = ignores tags (faster)
    "$BIN_DIR/repo" sync -j4 -c --no-tags --fail-fast

    info "Step 3/3: Restoring custom configurations..."
    local latest_backup
    latest_backup=$(readlink "$BACKUP_DIR/latest" 2>/dev/null || echo "")

    if [ -d "$latest_backup" ]; then
        local restored=0
        for rel_path in "${BACKUP_FILES[@]}"; do
            local src="$latest_backup/$rel_path"
            local dest="$BUILD_DIR/$rel_path"
            if [ -f "$src" ]; then
                mkdir -p "$(dirname "$dest")"
                cp "$src" "$dest"
                info "  Restaurado: $rel_path"
                ((restored++))
            fi
        done
        success "Safe sync complete! $restored file(s) restored."
    else
        warn "Most recent backup not found. Check manually at $BACKUP_DIR."
    fi
}

# =============================================================================
#  STEP 0: INITIAL SYSTEM CHECKS
# =============================================================================

step0_checks() {
    info "══════════════════════════════════════════"
    info "     Initial system checks"
    info "══════════════════════════════════════════"

    # Checks Linux distribution
    if ! grep -qi "ubuntu\|debian\|mint\|pop" /etc/os-release 2>/dev/null; then
        warn "Distro not recognized as Ubuntu/Debian."
        warn "This script was tested on Ubuntu 20.04/22.04/24.04, Linux Mint, and Debian."
        warn "On other distros, the dependency installer may not work."
        tip "On Arch/Manjaro, use the AUR. On Fedora, adapt packages for dnf."
    fi

    # Checks Python 3 (required for repo)
    if ! command -v python3 &>/dev/null; then
        error "Python 3 not found. Install it: sudo apt install python3"
    fi

    # Checks git
    if ! command -v git &>/dev/null; then
        error "git not found. Install it: sudo apt install git"
    fi

    # Checks disk space (recommended minimum: 400GB)
    # TIP: GMS ROMs may require up to 500GB. Vanilla usually ~200GB.
    check_space 400 "$HOME"

    # Checks RAM and swap
    check_ram_and_swap

    success "Initial checks complete."
}

# =============================================================================
#  STEP 1: INSTALL DEPENDENCIES
#  Packages required to build Android (based on Ubuntu/Debian)
# =============================================================================

step1_dependencies() {
    info "══════════════════════════════════════════"
    info "         Installing dependencies"
    info "══════════════════════════════════════════"
    tip "Requires internet connection and sudo permission."
    echo ""
    confirm "Install build packages now?" || return 0

    sudo apt update

    # Essential packages for building Android (AOSP and derivatives)
    sudo apt install -y \
        bc bison build-essential ccache curl flex \
        g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
        lib32readline-dev lib32z1-dev libdw-dev libelf-dev \
        libgnutls28-dev lz4 libsdl1.2-dev libssl-dev \
        libxml2 libxml2-utils lzop pngcrush rsync \
        schedtool squashfs-tools xsltproc zip zlib1g-dev \
        protobuf-compiler python3-protobuf \
        openjdk-11-jdk python-is-python3

    # libncurses5 — needed by some older ROMs, but not in Ubuntu 22.04+ repos
    if dpkg -l | grep -q "libncurses5 " 2>/dev/null; then
        success "libncurses5 already installed."
    else
        info "Trying to install libncurses5..."
        if apt-cache show libncurses5 &>/dev/null; then
            sudo apt install -y libncurses5 lib32ncurses5-dev libncurses5-dev
        else
            warn "libncurses5 not found in repositories."
            warn "Installing manually via Ubuntu 20.04 package..."
            tip "If this fails, ignore it. Not every ROM needs libncurses5."
            wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb 2>/dev/null && \
            wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb 2>/dev/null && \
            sudo dpkg -i libtinfo5_6.3-2_amd64.deb libncurses5_6.3-2_amd64.deb 2>/dev/null && \
            rm -f libtinfo5_6.3-2_amd64.deb libncurses5_6.3-2_amd64.deb || \
            warn "Manual installation of libncurses5 failed. Continue and check if it causes a build error."
        fi
    fi

    success "Dependencies installed."
    tip "If you encounter build errors due to missing packages, check the ROM's Wiki."
}

# =============================================================================
#  STEP 2: CONFIGURE BUILD ENVIRONMENT
#  Configures repo, git, ccache, and environment variables
# =============================================================================

step2_environment() {
    info "══════════════════════════════════════════"
    info "          Configuring environment"
    info "══════════════════════════════════════════"

    # Creates required directories
    # TIP: If any mkdir fails with "Permission denied" or "Not a directory",
    #      check that the path does not have a file with the same name.
    #      Example: if ~/android is a file, ~/android/rom cannot be created.
    #      Solution: rm ~/android (if it is a file) or change BUILD_DIR to another location.
    for dir in "$BIN_DIR" "$BUILD_DIR" "$BACKUP_DIR"; do
        mkdir -p "$dir" || error "Could not create: $dir\n Try creating manually: mkdir -p $dir"
        success "Directory OK: $dir"
    done

    # Installs the "repo" binary (Google's tool for managing AOSP source)
    if [ ! -f "$BIN_DIR/repo" ]; then
        info "Downloading repo tool..."
        curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$BIN_DIR/repo" || \
            error "Failed to download repo. Check your internet connection."
        chmod a+x "$BIN_DIR/repo"
        success "repo installed at $BIN_DIR/repo"
    else
        success "repo already exists at $BIN_DIR/repo."
    fi

    # Adds ~/bin to PATH in ~/.profile (persistent across sessions)
    if ! grep -q "HOME/bin" ~/.profile 2>/dev/null; then
        cat >> ~/.profile << 'EOF'

# Android build tools
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
EOF
        success "PATH updated in ~/.profile"
        tip "Run 'source ~/.profile' or open a new terminal to activate."
    else
        success "PATH already configured in ~/.profile"
    fi

    # Validates git configuration
    if [ "$GIT_EMAIL" = "you@example.com" ] || [ "$GIT_NAME" = "Your Name" ]; then
        error "GIT_EMAIL and GIT_NAME still have default values!\nEdit the script and fill in your real data at the top of the file."
    fi

    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_NAME"
    git lfs install
    git config --global trailer.changeid.key "Change-Id"
    success "Git configured: $GIT_NAME <$GIT_EMAIL>"

    # Configures ccache in ~/.bashrc (compilation cache — speeds up repeated builds)
    if ! grep -q "USE_CCACHE" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# ccache for Android builds
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR="$HOME/.ccache"
EOF
        success "ccache added to .bashrc"
    fi

    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    ccache -M "$CCACHE_SIZE"
    ccache -o compression=true
    success "ccache configured: ${CCACHE_SIZE}, compression enabled."

    # Java heap settings
    # TIP: Adjust -Xmx according to your available RAM:
    #   16GB RAM > -Xmx8g
    #   32GB RAM > -Xmx12g
    #   64GB RAM > -Xmx32g
    export _JAVA_OPTIONS="-Xmx6g -Xms512m"
    export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
    success "Java heap configured."
}

# =============================================================================
#  STEP 3: DOWNLOAD ROM SOURCE
#  Initializes repo and syncs the source (may take hours!)
# =============================================================================

step3_source() {
    info "══════════════════════════════════════════"
    info "          Downloading ROM source"
    info "══════════════════════════════════════════"
    warn "This can take a VERY long time depending on your connection."
    warn "The full source can take up 200-300GB of space!"
    echo ""
    tip "If the sync hangs or fails midway, run it again — it resumes from where it stopped."
    tip "If you get 'Connection reset' errors, try lowering -j (e.g.: -j2)."
    echo ""

    # WARNING: Verify that ROM_MANIFEST_URL is correct before continuing!
    if [[ "$ROM_MANIFEST_URL" == *"YourROM"* ]]; then
        error "ROM_MANIFEST_URL still has the default value!\nEdit the script and fill in the correct URL for your ROM's manifest."
    fi

    cd "$BUILD_DIR"

    if [ -d ".repo" ]; then
        warn "Repo already initialized at $BUILD_DIR. Skipping init."
        tip "If you want to switch ROMs, delete $BUILD_DIR and start from scratch."
    else
        confirm "Initialize repo (${ROM_MANIFEST_URL} @ ${BRANCH_ROM})?" || return 0
        "$BIN_DIR/repo" init \
            -u "$ROM_MANIFEST_URL" \
            -b "$BRANCH_ROM" \
            --git-lfs \
            --no-clone-bundle
        success "Repo initialized."
    fi

    confirm "Sync source now? (may take HOURS)" || return 0

    # Source sync
    # TIP: Adjust -j according to your connection. -j8 = 8 parallel downloads.
    #      On unstable connections, use -j2 or -j4.
    "$BIN_DIR/repo" sync -j4 -c --no-tags --fail-fast

    success "Source synced successfully."
}

# =============================================================================
#  STEP 4: CLONE DEVICE TREES
#  Clones device tree, kernel source, and vendor blobs
#
#  WARNING: You MUST find the correct repositories for your device!
#  Recommended sources:
#    - LineageOS: https://github.com/LineageOS
#    - TheMuppets (vendor blobs): https://github.com/TheMuppets
#    - XDA Developers: https://xdaforums.com
#    - Your device's or ROM's Telegram group
# =============================================================================

step4_device_trees() {
    info "══════════════════════════════════════════"
    info "          Cloning device trees"
    info "══════════════════════════════════════════"
    warn "IMPORTANT: Verify that the URLs below are correct for your device!"
    warn "If the repository does not exist, you will need to find it manually."
    tip "Search on GitHub: android_device_${MANUFACTURER}_${DEVICE}"
    echo ""

    # Checks if variables are set
    if [ "$DEVICE" = "your_codename_here" ]; then
        error "DEVICE variable not configured! Edit the script and fill in your device codename."
    fi

    cd "$BUILD_DIR"

    # ── Device tree ──────────────────────────────────────────────────────────
    local device_path="device/${MANUFACTURER}/${DEVICE}"
    if [ ! -d "$device_path" ]; then
        info "Cloning device tree to: $device_path"
        # TIP: If you get a "repository not found" error, the URL is wrong.
        #      Search for the correct repository on GitHub or XDA.
        # TIP: If mkdir fails, check write permissions on device/${MANUFACTURER}.
        mkdir -p "device/${MANUFACTURER}"
        git clone "$DEVICE_TREE_URL" \
            -b "$BRANCH_DEVICE" \
            "$device_path" || {
            warn "Failed to clone device tree."
            tip "Check the URL: $DEVICE_TREE_URL"
            tip "And the branch: $BRANCH_DEVICE"
            tip "Search for the correct repository on GitHub or XDA Developers."
            error "Device tree clone failed."
        }
        success "Device tree cloned to: $device_path"
    else
        success "Device tree already exists: $device_path"
    fi

    # ── Kernel source ────────────────────────────────────────────────────────
    # NOTE: Not every ROM requires recompiling the kernel.
    # Check your ROM's documentation to see if cloning the kernel is necessary.
    local kernel_path="kernel/${MANUFACTURER}/$(basename "$KERNEL_REPO_URL" .git | sed 's/android_kernel_[^_]*_//')"
    if [ ! -d "$kernel_path" ]; then
        info "Cloning kernel source..."
        tip "If your ROM uses a precompiled kernel, you can skip this step."
        mkdir -p "$(dirname "$kernel_path")"
        git clone "$KERNEL_REPO_URL" "$kernel_path" || {
            warn "Failed to clone kernel."
            tip "Check the URL: $KERNEL_REPO_URL"
            tip "If there is no kernel source, check if the ROM uses a 'vendor kernel' (precompiled)."
            warn "Continuing without cloned kernel — may cause a build error if required."
        }
    else
        success "Kernel already exists: $kernel_path"
    fi

    # ── Vendor blobs ─────────────────────────────────────────────────────────
    local vendor_path="vendor/${MANUFACTURER}/${DEVICE}"
    if [ ! -d "$vendor_path" ]; then
        info "Cloning vendor blobs..."
        tip "If the repository does not exist on TheMuppets, try extracting from stock firmware."
        tip "Veja: https://wiki.lineageos.org/extracting_blobs_from_zips"
        mkdir -p "vendor/${MANUFACTURER}"
        git clone "$VENDOR_REPO_URL" \
            -b "$BRANCH_DEVICE" \
            "$vendor_path" || {
            warn "Failed to clone vendor blobs."
            tip "Check the URL: $VENDOR_REPO_URL"
            tip "Alternatives:"
            tip "  1. TheMuppets: https://github.com/TheMuppets"
            tip "  2. Extract from stock firmware with extract-files.sh"
            tip "  3. Ask the ROM maintainer on Telegram/XDA"
            error "Vendor blobs clone failed."
        }
        success "Vendor blobs cloned to: $vendor_path"
    else
        success "Vendor blobs already exist: $vendor_path"
    fi

    success "Device trees ready."
    echo ""
    tip "If your ROM requires additional repos (e.g.: common device tree, soc-vendor),"
    tip "clone them manually before building. See the device tree documentation."
}

# =============================================================================
#  STEP 5: PATCHES / ROM-SPECIFIC CONFIGURATIONS
#  Adjust according to your ROM and device needs.
#  This step is highly specific — use as a template.
# =============================================================================

step5_patches() {
    info "══════════════════════════════════════════"
    info "   Applying ROM patches/configurations"
    info "══════════════════════════════════════════"
    warn "This step is specific to each ROM and device."
    warn "By default, no patches are applied."
    echo ""
    tip "If your ROM requires patches in the device tree, add them here."
    tip "Common examples:"
    tip "  - Adding ROM variables to device.mk"
    tip "  - Modifying properties in lineage_<device>.mk or <rom>_<device>.mk"
    tip "  - Adding specific configuration files"
    echo ""

    # EXAMPLE: How to add variables to device.mk
    # Uncomment and adapt as needed:
    #
    # local device_mk="$BUILD_DIR/device/${MANUFACTURER}/${DEVICE}/device.mk"
    #
    # if grep -q "MyROM" "$device_mk" 2>/dev/null; then
    #     warn "Patches already applied. Skipping."
    #     return 0
    # fi
    #
    # cp "$device_mk" "${device_mk}.bak"
    # cat >> "$device_mk" << 'EOF'
    #
    # # ── ROM Configuration ──────────────────────────────────────────────────
    # TARGET_DISABLE_EPPE := true
    # MY_ROM_MAINTAINER := Your Name
    # EOF
    #
    # success "Patches applied to device.mk"

    info "No default patches applied."
    tip "Edit the step5_patches() function in the script to add your patches."
}

# =============================================================================
#  STEP 6: BUILD THE ROM
#  Configures the environment and starts compilation
# =============================================================================

step6_build() {
    info "══════════════════════════════════════════"
    info "           Building the ROM"
    info "══════════════════════════════════════════"

    # Selects variant before building
    select_variant

    echo ""
    echo -e "  Device      : ${GREEN}$DEVICE${NC}"
    echo -e "  Variant     : ${GREEN}$BUILD_TYPE${NC}"
    echo -e "  Threads     : ${GREEN}$JOBS${NC}"
    echo -e "  ROM Branch  : ${GREEN}$BRANCH_ROM${NC}"
    echo ""
    warn "Build time varies greatly depending on hardware:"
    warn "  Weak CPU (4 cores, 16GB RAM)      : 16hrs - 2 days"
    warn "  Mid CPU (8 cores, 16GB RAM+)      : 2-6 hours"
    warn "  Powerful CPU (12+ cores, 32GB+)   : 30min-2 hours"
    warn "  With ccache (subsequent builds)   : much faster"
    echo ""
    confirm "Start build now?" || return 0

    cd "$BUILD_DIR"

    # Environment settings for the build
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    export CCACHE_COMPRESSION=1
    export NINJA_ARGS="-j${JOBS}"
    export _JAVA_OPTIONS="-Xmx6g -Xms512m"

    # Loads the Android build environment (envsetup.sh)
    # TIP: If "source build/envsetup.sh" fails, check if the source was
    #      synced correctly (step [4]).
    if [ ! -f "$BUILD_DIR/build/envsetup.sh" ]; then
        error "build/envsetup.sh not found!\nCheck if the source was synced (step [4])."
    fi

    source build/envsetup.sh

    # Generates signing keys (only required on the first run)
    # TIP: Keys identify your builds. Do not delete them after generation!
    #      If you lose the keys, future builds will not be compatible with previous ones.
    local CERT_DIR="$BUILD_DIR/certs"
    if [ ! -d "$CERT_DIR" ]; then
        info "Generating private keys at: $CERT_DIR"
        mkdir -p "$CERT_DIR" || error "Could not create $CERT_DIR. Try: mkdir -p $CERT_DIR"
        cd "$CERT_DIR"

        for cert in releasekey platform shared media networkstack testkey; do
            info "  Generating: $cert"
            openssl genrsa -out "${cert}.pem" 4096 2>/dev/null
            openssl req -new -x509 -key "${cert}.pem" \
                -out "${cert}.x509.pem" \
                -days 10000 \
                -subj "/C=US/ST=State/L=City/O=Android/OU=Android/CN=Android" \
                2>/dev/null
            openssl pkcs8 -in "${cert}.pem" -topk8 -nocrypt \
                -out "${cert}.pk8" -outform DER \
                2>/dev/null
            rm "${cert}.pem"
        done

        cd "$BUILD_DIR"
        success "Keys generated at: $CERT_DIR"
        warn "KEEP THESE KEYS! Without them, you cannot update your ROM without a wipe."
    else
        success "Keys already exist at $CERT_DIR — skipping generation."
    fi

    # Configures the build target
    # TIP: "breakfast" is the standard command for LineageOS/derivatives to configure the target.
    #      Some ROMs use custom commands (e.g.: "axion" for AxionOS, "crave" for CrDroid).
    #      Check your ROM's documentation!
    info "Configuring target: $DEVICE ($BUILD_TYPE)"
    if command -v breakfast &>/dev/null; then
        breakfast "$DEVICE" "$BUILD_TYPE" || \
            error "breakfast failed. Check if the device tree is correct (step [5])."
    else
        warn "Command 'breakfast' not found."
        tip "Some ROMs use custom commands. Try manually:"
        tip "  lunch <rom>_${DEVICE}-${BUILD_TYPE}"
        tip "  Or check the ROM documentation for the correct command."
        error "Configure the target manually and use option [7] again."
    fi

    # Starts the build
    local log_file="$BUILD_DIR/build_${BUILD_TYPE}_$(date +%Y%m%d_%H%M).log"
    info "Starting build with $JOBS threads..."
    info "Log at: $log_file"
    echo ""

    # Tries common build commands for different ROMs
    # TIP: Adapt according to your ROM:
    #   LineageOS / derivatives → brunch <device>
    #   PixelOS                 → m bacon
    #   Some ROMs               → mka bacon or mka <rom>
    if command -v brunch &>/dev/null; then
        brunch "$DEVICE" 2>&1 | tee "$log_file"
    else
        warn "Command 'brunch' not found. Trying 'm bacon'..."
        m bacon -j"$JOBS" 2>&1 | tee "$log_file" || \
            error "Build failed. Check the log at: $log_file"
    fi

    echo ""
    success "════════════════════════════════════════════"
    success " Build complete!"
    success "════════════════════════════════════════════"
    info "Output files at: $BUILD_DIR/out/target/product/$DEVICE/"

    # Lista os arquivos .zip gerados
    local zips
    zips=$(ls -lh "$BUILD_DIR/out/target/product/$DEVICE/"*.zip 2>/dev/null)
    if [ -n "$zips" ]; then
        echo "$zips"
    else
        warn "No .zip found. Check the log: $log_file"
        tip "Look for 'error:' or 'FAILED:' in the log to identify the issue."
    fi
}

# =============================================================================
#  DIAGNOSTICS: Checks branches of cloned repositories
#  Useful for identifying incorrect branch issues
# =============================================================================

step_diagnose() {
    info "══════════════════════════════════════════════════"
    info "      Checking repository branches"
    info "══════════════════════════════════════════════════"
    tip "Wrong branches are a common cause of build errors."
    echo ""

    # Repository → expected branch map
    # TIP: Add here the repositories you cloned manually
    declare -A expected_branches=(
        ["device/${MANUFACTURER}/${DEVICE}"]="$BRANCH_DEVICE"
        ["vendor/${MANUFACTURER}/${DEVICE}"]="$BRANCH_DEVICE"
        # Add others as needed:
        # ["device/${MANUFACTURER}/${DEVICE}-common"]="$BRANCH_DEVICE"
        # ["kernel/${MANUFACTURER}/chipset"]="$BRANCH_DEVICE"
    )

    local all_ok=true

    for rel_path in "${!expected_branches[@]}"; do
        local full_path="$BUILD_DIR/$rel_path"
        local expected="${expected_branches[$rel_path]}"

        if [ ! -d "$full_path" ]; then
            warn "  NOT FOUND: $rel_path"
            all_ok=false
            continue
        fi

        local current
        current=$(git -C "$full_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "erro")
        local last_commit
        last_commit=$(git -C "$full_path" log -1 --format="%h %s" 2>/dev/null || echo "N/A")

        if [ "$current" = "$expected" ]; then
            success "  OK  $rel_path"
            info "       Branch: $current | Commit: $last_commit"
        else
            warn "  WRONG BRANCH: $rel_path"
            warn "       Expected : $expected"
            warn "       Current  : $current"
            warn "       Commit   : $last_commit"
            all_ok=false

            tip "To fix: cd $BUILD_DIR/$rel_path"
            tip "        git fetch origin $expected"
            tip "        git checkout $expected"
        fi
    done

    echo ""
    if $all_ok; then
        success "All repositories are on the correct branches."
    else
        warn "One or more repositories have an incorrect branch."
        warn "Wrong branches cause errors like 'soong bootstrap failed' or 'module not found'."
    fi
}

# =============================================================================
#  MENU PRINCIPAL
# =============================================================================

show_menu() {
    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                         < BRG-SH >                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Device        : ${GREEN}${DEVICE}${NC} (${MANUFACTURER})"
    echo -e "  ROM Branch    : ${GREEN}${BRANCH_ROM}${NC}"
    echo -e "  DevTree Branch: ${GREEN}${BRANCH_DEVICE}${NC}"
    echo -e "  Directory     : ${BLUE}${BUILD_DIR}${NC}"
    echo -e "  Backup        : ${BLUE}${BACKUP_DIR}${NC}"
    echo -e "  Threads       : ${GREEN}${JOBS}${NC}"
    echo -e "  Variant       : ${GREEN}${BUILD_TYPE}${NC}"
    echo ""
    echo "  ── Setup (first time) ───────────────────────────────────"
    echo "  [0] Everything from scratch (all steps in sequence)"
    echo "  [1] Initial system checks"
    echo "  [2] Install dependencies"
    echo "  [3] Configure environment (repo, git, ccache)"
    echo "  [4] Download ROM source"
    echo "  [5] Clone device trees (device / kernel / vendor)"
    echo "  [6] Apply ROM patches/configurations"
    echo ""
    echo "  ── Build ─────────────────────────────────────────────────"
    echo "  [7] Compile (asks for variant first)"
    echo "  [v] Change build variant"
    echo ""
    echo "  ── Backup & Sync ─────────────────────────────────────────"
    echo "  [b] Backup custom configurations"
    echo "  [r] Restore backup (choose which)"
    echo "  [s] Safe sync (backup → sync → auto-restore)"
    echo ""
    echo "  ── Diagnostics ───────────────────────────────────────────"
    echo "  [d] Check repository branches"
    echo ""
    echo "  [q] Exit"
    echo ""
}

main() {
    while true; do
        show_menu
        read -rp "$(echo -e "${YELLOW}Opção: ${NC}")" opt

        case "$opt" in
            0)
                step0_checks && \
                step1_dependencies && \
                step2_environment && \
                step3_source && \
                step4_device_trees && \
                step5_patches && \
                step6_build || true
                pause_menu
                ;;
            1) step0_checks     || true; pause_menu ;;
            2) step1_dependencies || true; pause_menu ;;
            3) step2_environment || true; pause_menu ;;
            4) step3_source     || true; pause_menu ;;
            5) step4_device_trees || true; pause_menu ;;
            6) step5_patches    || true; pause_menu ;;
            7) step6_build      || true; pause_menu ;;
            v|V) select_variant || true; pause_menu ;;
            b|B) step_backup_save    || true; pause_menu ;;
            r|R) step_backup_restore || true; pause_menu ;;
            s|S) step_sync_safe      || true; pause_menu ;;
            d|D) step_diagnose       || true; pause_menu ;;
            q|Q)
                echo ""
                info "Exiting. Happy building!"
                echo ""
                exit 0
                ;;
            "")
                # Enter vazio: redesenha o menu sem mensagem de erro
                ;;
            *)
                warn "Invalid option: '$opt'"
                sleep 1
                ;;
        esac
    done
}

# Entry point
main
