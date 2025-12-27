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
parted "$INSTALL_DEVICE" --script -- mkpart ESP fat32 1MB 512MB
parted "$INSTALL_DEVICE" --script -- set 1 esp on
parted "$INSTALL_DEVICE" --script -- mkpart root ext4 512MB 100%

# Determine partition names
if [[ "$INSTALL_DEVICE" == *"nvme"* ]] || [[ "$INSTALL_DEVICE" == *"mmcblk"* ]]; then
    BOOT_PART="${INSTALL_DEVICE}p1"
    ROOT_PART="${INSTALL_DEVICE}p2"
else
    BOOT_PART="${INSTALL_DEVICE}1"
    ROOT_PART="${INSTALL_DEVICE}2"
fi

# =========================
# Formatting
# =========================
print_step "Formatting partitions..."
mkfs.fat -F 32 -n boot "$BOOT_PART"
mkfs.ext4 -F -L nixos "$ROOT_PART"

# =========================
# Mounting
# =========================
print_step "Mounting..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "$BOOT_PART" /mnt/boot

# =========================
# Config generation
# =========================
print_step "Generating hardware config..."
nixos-generate-config --root /mnt

# =========================
# Copy repo into installed system
# =========================
print_step "Copying nixos-config repository into installed system..."
mkdir -p "/mnt$USER_HOME"
cp -rv . "/mnt$CONFIG_DEST"

print_step "Moving hardware-configuration.nix into nixos-config..."
mv /mnt/etc/nixos/hardware-configuration.nix "/mnt$CONFIG_DEST/hosts/bau-desktop/hardware-configuration.nix"

print_step "Removing temporary /etc/nixos..."
rm -rf /mnt/etc/nixos

# =========================
# NixOS Installation
# =========================
print_step "Installing NixOS..."

INSTALL_FLAGS="--no-root-password"

# If flake.lock doesn't exist, add the flag to skip writing it
if [ ! -f "/mnt$CONFIG_DEST/flake.lock" ]; then
    print_step "Lockfile not found. Adding --no-write-lock-file to bypass assertion error."
    INSTALL_FLAGS="$INSTALL_FLAGS --no-write-lock-file"
fi

nixos-install $INSTALL_FLAGS --flake "/mnt$CONFIG_DEST#bau-desktop"

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
