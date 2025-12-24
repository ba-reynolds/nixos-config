#!/usr/bin/env bash
set -e

# =========================
# Variables
# =========================
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

USER_NAME="bau"
USER_HOME="/home/$USER_NAME"

INSTALL_DEVICE="${1:-}"
LOG_DEVICE="${2:-}"

ROOT_PART=""
SWAP_PART=""
BOOT_PART=""
CONFIG_DEST="$USER_HOME/nixos-config"

# =========================
# Functions
# =========================
print_step() {
    echo -e "${GREEN}==> $1${NC}"
}

print_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# =========================
# Checks
# =========================
[ "$EUID" -ne 0 ] && print_error "Run as root"

if [ -z "$INSTALL_DEVICE" ] || [ -z "$LOG_DEVICE" ]; then
    print_error "Usage: $0 <install-device> <log-device>
Example: $0 /dev/sda /dev/sdb"
fi

[ ! -b "$INSTALL_DEVICE" ] && print_error "Install device $INSTALL_DEVICE not found"
[ ! -b "$LOG_DEVICE" ] && print_error "Log device $LOG_DEVICE not found"

# Mount log device to temporary location
LOG_MNT="/mnt-log"
mkdir -p "$LOG_MNT"
mount "$LOG_DEVICE" "$LOG_MNT" || print_error "Failed to mount log device $LOG_DEVICE"

# Redirect all output to log file on the log device
exec > >(tee -a "$LOG_MNT/nixos-install.log")
exec 2>&1

print_step "Logging to $LOG_MNT/nixos-install.log"

# =========================
# Partitioning
# =========================
print_step "Partitioning $INSTALL_DEVICE..."
parted "$INSTALL_DEVICE" --script -- mklabel gpt
parted "$INSTALL_DEVICE" --script -- mkpart root ext4 512MB -8GB
parted "$INSTALL_DEVICE" --script -- mkpart swap linux-swap -8GB 100%
parted "$INSTALL_DEVICE" --script -- mkpart ESP fat32 1MB 512MB
parted "$INSTALL_DEVICE" --script -- set 3 esp on

# Determine partition names
if [[ "$INSTALL_DEVICE" == *"nvme"* ]] || [[ "$INSTALL_DEVICE" == *"mmcblk"* ]]; then
    ROOT_PART="${INSTALL_DEVICE}p1"
    SWAP_PART="${INSTALL_DEVICE}p2"
    BOOT_PART="${INSTALL_DEVICE}p3"
else
    ROOT_PART="${INSTALL_DEVICE}1"
    SWAP_PART="${INSTALL_DEVICE}2"
    BOOT_PART="${INSTALL_DEVICE}3"
fi

# =========================
# Formatting
# =========================
print_step "Formatting partitions..."
mkfs.ext4 -F -L nixos "$ROOT_PART"
mkswap -L swap "$SWAP_PART"
mkfs.fat -F 32 -n boot "$BOOT_PART"

# =========================
# Mounting
# =========================
print_step "Mounting..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "$BOOT_PART" /mnt/boot
# swapon "$SWAP_PART" # uncomment this to enable swapping

# =========================
# Config generation
# =========================
print_step "Generating config..."
nixos-generate-config --root /mnt

print_step "Copying local config files..."
# Copy all .nix files from current directory
for nixfile in *.nix; do
    [ -e "$nixfile" ] || continue
    cp -v "$nixfile" /mnt/etc/nixos/
done

# Copy dotfiles directory if it exists
if [ -d "./dotfiles" ]; then
    print_step "Copying dotfiles directory..."
    cp -rv ./dotfiles /mnt/etc/nixos/
fi

# Copy modules directory if it exists
if [ -d "./modules" ]; then
    print_step "Copying modules directory..."
    cp -rv ./modules /mnt/etc/nixos/
fi

# =========================
# NixOS Installation
# =========================
print_step "Installing NixOS..."

INSTALL_FLAGS="--no-root-password"

# If flake.lock doesn't exist, add the flag to skip writing it
if [ ! -f "/mnt/etc/nixos/flake.lock" ]; then
    print_step "Lockfile not found. Adding --no-write-lock-file to bypass assertion error."
    INSTALL_FLAGS="$INSTALL_FLAGS --no-write-lock-file"
fi

nixos-install $INSTALL_FLAGS --flake /mnt/etc/nixos#bau-pc

# =========================
# Move config to user directory
# =========================
print_step "Moving config to user directory..."
mkdir -p "/mnt$CONFIG_DEST"
mv /mnt/etc/nixos/* "/mnt$CONFIG_DEST/"
rmdir /mnt/etc/nixos


# =========================
# Password setup
# =========================
print_step "Setting root password..."
nixos-enter --root /mnt -c "passwd root"

print_step "Setting $USER_NAME password..."
nixos-enter --root /mnt -c "passwd $USER_NAME"

# =========================
# Cleanup log mount
# =========================
umount "$LOG_MNT"
rmdir "$LOG_MNT"

print_step "Done! Reboot and remove USB."
