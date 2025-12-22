#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}==> $1${NC}"
}

print_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Check root
[ "$EUID" -ne 0 ] && print_error "Run as root"

# Args
DEVICE="${1:-}"

[ -z "$DEVICE" ] && print_error "Usage: $0 <device>
Example: $0 /dev/sda"

# Verify device
[ ! -b "$DEVICE" ] && print_error "Device $DEVICE not found"

# Partition disk (following official NixOS manual)
print_step "Partitioning $DEVICE..."
parted "$DEVICE" --script -- mklabel gpt
parted "$DEVICE" --script -- mkpart root ext4 512MB -8GB
parted "$DEVICE" --script -- mkpart swap linux-swap -8GB 100%
parted "$DEVICE" --script -- mkpart ESP fat32 1MB 512MB
parted "$DEVICE" --script -- set 3 esp on

# Determine partition names
if [[ "$DEVICE" == *"nvme"* ]] || [[ "$DEVICE" == *"mmcblk"* ]]; then
    ROOT="${DEVICE}p1"
    SWAP="${DEVICE}p2"
    BOOT="${DEVICE}p3"
else
    ROOT="${DEVICE}1"
    SWAP="${DEVICE}2"
    BOOT="${DEVICE}3"
fi

# Format
print_step "Formatting partitions..."
mkfs.ext4 -F -L nixos "$ROOT"
mkswap -L swap "$SWAP"
mkfs.fat -F 32 -n boot "$BOOT"

# Mount
print_step "Mounting..."
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "$BOOT" /mnt/boot
swapon "$SWAP"

# Generate config
print_step "Generating config..."
nixos-generate-config --root /mnt

# Copy local config files
print_step "Copying local config files..."
cp -v config/*.nix /mnt/etc/nixos/ 2>/dev/null || print_error "No .nix files found"

# Install
print_step "Installing NixOS..."
nixos-install --no-root-password

print_step "Done! Reboot and remove USB."
