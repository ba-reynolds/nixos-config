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

DEVICE="${1:-}"

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

[ -z "$DEVICE" ] && print_error "Usage: $0 <device>
Example: $0 /dev/sda"

[ ! -b "$DEVICE" ] && print_error "Device $DEVICE not found"

# =========================
# Partitioning
# =========================
print_step "Partitioning $DEVICE..."
parted "$DEVICE" --script -- mklabel gpt
parted "$DEVICE" --script -- mkpart root ext4 512MB -8GB
parted "$DEVICE" --script -- mkpart swap linux-swap -8GB 100%
parted "$DEVICE" --script -- mkpart ESP fat32 1MB 512MB
parted "$DEVICE" --script -- set 3 esp on

# Determine partition names
if [[ "$DEVICE" == *"nvme"* ]] || [[ "$DEVICE" == *"mmcblk"* ]]; then
    ROOT_PART="${DEVICE}p1"
    SWAP_PART="${DEVICE}p2"
    BOOT_PART="${DEVICE}p3"
else
    ROOT_PART="${DEVICE}1"
    SWAP_PART="${DEVICE}2"
    BOOT_PART="${DEVICE}3"
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
swapon "$SWAP_PART"

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

# Copy config directory if it exists
if [ -d "./config" ]; then
    print_step "Copying config directory..."
    cp -rv ./config /mnt/etc/nixos/
fi


print_step "Syncing files to disk..."
sync
sleep 2  # Give the filesystem a moment to settle

# Verify files are actually there
print_step "Verifying copied files..."
ls -la /mnt/etc/nixos/
[ -f "/mnt/etc/nixos/flake.nix" ] || print_error "flake.nix not found after copy!"
[ -f "/mnt/etc/nixos/configuration.nix" ] || print_error "configuration.nix not found after copy!"
[ -f "/mnt/etc/nixos/home.nix" ] || print_error "home.nix not found after copy!"


# =========================
# NixOS Installation
# =========================
print_step "Installing NixOS..."
nixos-install --no-root-password --flake /mnt/etc/nixos#bau-pc

# =========================
# Move config to user directory
# =========================
print_step "Moving config to user directory..."
mkdir -p "/mnt$CONFIG_DEST"
mv /mnt/etc/nixos/* "/mnt$CONFIG_DEST/"
rmdir /mnt/etc/nixos

print_step "Setting ownership of config files..."
chroot /mnt chown -R $USER_NAME:$USER_NAME "$CONFIG_DEST"

# =========================
# Password setup
# =========================
print_step "Setting root password..."
nixos-enter --root /mnt -c "passwd root"

print_step "Setting $USER_NAME password..."
nixos-enter --root /mnt -c "passwd $USER_NAME"

print_step "Done! Reboot and remove USB."