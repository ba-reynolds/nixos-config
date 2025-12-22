I've been trying to install nixos for quite some time now, I'm always getting the same assertion error at the end and I'm not sure why...

```
# flake.nix
{
  description = "Hyprland on Nixos";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs: {
    nixosConfigurations.bau-pc = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.bau = import ./home.nix;
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
```

```
#home.nix
{ config, pkgs, ... }:
{
  home.username = "bau";
  home.stateVersion = "25.11";
  programs.git.enable = true;
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#bau-pc";
    };
    initExtra = ''
      export PS1='\[\e[38;5;76m\]\u\[\e[0m\] in \[\e[38;5;32m\]\w\[\e[0m\] \\$ '
    '';
    profileExtra = ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
          exec hyprland
      fi
    '';
  };

  xdg.configFile = {
    waybar.source = ./config/waybar;
  };
}
```

```
#configuration.nix
{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bau-pc"; 
  networking.networkmanager.enable = true;
  services.getty.autologinUser = "bau";

  time.timeZone = "America/Argentina/Buenos_Aires";
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.bau = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox.enable = true;
  programs.hyprland.enable = true;


  environment.systemPackages = with pkgs; [
    vim
    wget
    bat
    waybar
    kitty
    hyprpaper
  ];

  system.stateVersion = "25.11"; # Did you read the comment?
}
```

```
# Installation script
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

# Copy config directory if it exists
if [ -d "./config" ]; then
    print_step "Copying config directory..."
    cp -rv ./config /mnt/etc/nixos/
fi

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

# =========================
# Cleanup log mount
# =========================
umount "$LOG_MNT"
rmdir "$LOG_MNT"

print_step "Done! Reboot and remove USB."
```

Installation Log
```
[0;32m==> Logging to /mnt-log/nixos-install.log[0m
[0;32m==> Partitioning /dev/nvme0n1...[0m
[0;32m==> Formatting partitions...[0m
mke2fs 1.47.3 (8-Jul-2025)
Discarding device blocks:         0/247973120101711872/247973120                   done                            
Creating filesystem with 247973120 4k blocks and 61997056 inodes
Filesystem UUID: 7d915563-9029-491b-a1f5-9b471a5470a1
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208, 
	4096000, 7962624, 11239424, 20480000, 23887872, 71663616, 78675968, 
	102400000, 214990848

Allocating group tables:    0/7568         done                            
Writing inode tables:    0/7568         done                            
Creating journal (262144 blocks): done
Writing superblocks and filesystem accounting information:    0/7568         done

mkswap: /dev/nvme0n1p2: warning: wiping old swap signature.
Setting up swapspace version 1, size = 7.5 GiB (7999582208 bytes)
LABEL=swap, UUID=3b0cad7a-96d1-443a-8917-51d65175e37b
mkfs.fat: Warning: lowercase labels might not work properly on some systems
mkfs.fat 4.2 (2021-01-31)
[0;32m==> Mounting...[0m
[0;32m==> Generating config...[0m
writing /mnt/etc/nixos/hardware-configuration.nix...
writing /mnt/etc/nixos/configuration.nix...
For more hardware-specific settings, see https://github.com/NixOS/nixos-hardware.
[0;32m==> Copying local config files...[0m
'configuration.nix' -> '/mnt/etc/nixos/configuration.nix'
'flake.nix' -> '/mnt/etc/nixos/flake.nix'
'home.nix' -> '/mnt/etc/nixos/home.nix'
[0;32m==> Copying config directory...[0m
'./config' -> '/mnt/etc/nixos/config'
'./config/waybar' -> '/mnt/etc/nixos/config/waybar'
'./config/waybar/config.jsonc' -> '/mnt/etc/nixos/config/waybar/config.jsonc'
'./config/waybar/style.css' -> '/mnt/etc/nixos/config/waybar/style.css'
[0;32m==> Installing NixOS...[0m
unpacking 'github:nix-community/home-manager/527ad07e6625302b648ed3b28c34b62a79bd103e' into the Git cache...
unpacking 'github:hyprwm/Hyprland/60efbf3f63bec3100477ea9ba6cd634e35d5aeaa' into the Git cache...
unpacking 'github:NixOS/nixpkgs/a6531044f6d0bef691ea18d4d4ce44d0daa6e816' into the Git cache...
warning: creating lock file "/mnt/etc/nixos/flake.lock": 
• Added input 'home-manager':
    'github:nix-community/home-manager/527ad07e6625302b648ed3b28c34b62a79bd103e?narHash=sha256-AjK3/UKDzeXFeYNLVBaJ3%2BHLE9he1g5UrlNd4/BM3eA%3D' (2025-12-22)
• Added input 'home-manager/nixpkgs':
    follows 'nixpkgs'
• Added input 'hyprland':
    'github:hyprwm/Hyprland/60efbf3f63bec3100477ea9ba6cd634e35d5aeaa?narHash=sha256-6E6k/T6fPXtyhT35wXSv1h3qTQrEbNbDVaMEXiYQ2Xs%3D' (2025-12-21)
• Added input 'hyprland/aquamarine':
    'github:hyprwm/aquamarine/d83c97f8f5c0aae553c1489c7d9eff3eadcadace?narHash=sha256-%2Bhn8v9jkkLP9m%2Bo0Nm5SiEq10W0iWDSotH2XfjU45fA%3D' (2025-12-16)
• Added input 'hyprland/aquamarine/hyprutils':
    follows 'hyprland/hyprutils'
• Added input 'hyprland/aquamarine/hyprwayland-scanner':
    follows 'hyprland/hyprwayland-scanner'
• Added input 'hyprland/aquamarine/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/aquamarine/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprcursor':
    'github:hyprwm/hyprcursor/44e91d467bdad8dcf8bbd2ac7cf49972540980a5?narHash=sha256-lIqabfBY7z/OANxHoPeIrDJrFyYy9jAM4GQLzZ2feCM%3D' (2025-07-31)
• Added input 'hyprland/hyprcursor/hyprlang':
    follows 'hyprland/hyprlang'
• Added input 'hyprland/hyprcursor/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprcursor/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprgraphics':
    'github:hyprwm/hyprgraphics/8f1bec691b2d198c60cccabca7a94add2df4ed1a?narHash=sha256-JnET78yl5RvpGuDQy3rCycOCkiKoLr5DN1fPhRNNMco%3D' (2025-11-21)
• Added input 'hyprland/hyprgraphics/hyprutils':
    follows 'hyprland/hyprutils'
• Added input 'hyprland/hyprgraphics/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprgraphics/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprland-guiutils':
    'github:hyprwm/hyprland-guiutils/e50ae912813bdfa8372d62daf454f48d6df02297?narHash=sha256-CCGohW5EBIRy4B7vTyBMqPgsNcaNenVad/wszfddET0%3D' (2025-12-13)
• Added input 'hyprland/hyprland-guiutils/aquamarine':
    follows 'hyprland/aquamarine'
• Added input 'hyprland/hyprland-guiutils/hyprgraphics':
    follows 'hyprland/hyprgraphics'
• Added input 'hyprland/hyprland-guiutils/hyprlang':
    follows 'hyprland/hyprlang'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit':
    'github:hyprwm/hyprtoolkit/5cfe0743f0e608e1462972303778d8a0859ee63e?narHash=sha256-7CcO%2BwbTJ1L1NBQHierHzheQGPWwkIQug/w%2BfhTAVuU%3D' (2025-12-01)
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/aquamarine':
    follows 'hyprland/hyprland-guiutils/aquamarine'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/hyprgraphics':
    follows 'hyprland/hyprland-guiutils/hyprgraphics'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/hyprlang':
    follows 'hyprland/hyprland-guiutils/hyprlang'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/hyprutils':
    follows 'hyprland/hyprland-guiutils/hyprutils'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/hyprwayland-scanner':
    follows 'hyprland/hyprland-guiutils/hyprwayland-scanner'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/nixpkgs':
    follows 'hyprland/hyprland-guiutils/nixpkgs'
• Added input 'hyprland/hyprland-guiutils/hyprtoolkit/systems':
    follows 'hyprland/hyprland-guiutils/systems'
• Added input 'hyprland/hyprland-guiutils/hyprutils':
    follows 'hyprland/hyprutils'
• Added input 'hyprland/hyprland-guiutils/hyprwayland-scanner':
    follows 'hyprland/hyprwayland-scanner'
• Added input 'hyprland/hyprland-guiutils/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprland-guiutils/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprland-protocols':
    'github:hyprwm/hyprland-protocols/3f3860b869014c00e8b9e0528c7b4ddc335c21ab?narHash=sha256-P9zdGXOzToJJgu5sVjv7oeOGPIIwrd9hAUAP3PsmBBs%3D' (2025-12-08)
• Added input 'hyprland/hyprland-protocols/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprland-protocols/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprlang':
    'github:hyprwm/hyprlang/0d00dc118981531aa731150b6ea551ef037acddd?narHash=sha256-54ltTSbI6W%2BqYGMchAgCR6QnC1kOdKXN6X6pJhOWxFg%3D' (2025-12-01)
• Added input 'hyprland/hyprlang/hyprutils':
    follows 'hyprland/hyprutils'
• Added input 'hyprland/hyprlang/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprlang/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprutils':
    'github:hyprwm/hyprutils/5ac060bfcf2f12b3a6381156ebbc13826a05b09f?narHash=sha256-roINUGikWRqqgKrD4iotKbGj3ZKJl3hjMz5l/SyKrHw%3D' (2025-12-19)
• Added input 'hyprland/hyprutils/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprutils/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprwayland-scanner':
    'github:hyprwm/hyprwayland-scanner/f6cf414ca0e16a4d30198fd670ec86df3c89f671?narHash=sha256-Uan1Nl9i4TF/kyFoHnTq1bd/rsWh4GAK/9/jDqLbY5A%3D' (2025-11-20)
• Added input 'hyprland/hyprwayland-scanner/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprwayland-scanner/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/hyprwire':
    'github:hyprwm/hyprwire/1079777525b30a947c8d657fac158e00ae85de9d?narHash=sha256-26qPwrd3od%2BxoYVywSB7hC2cz9ivN46VPLlrsXyGxvE%3D' (2025-12-20)
• Added input 'hyprland/hyprwire/hyprutils':
    follows 'hyprland/hyprutils'
• Added input 'hyprland/hyprwire/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/hyprwire/systems':
    follows 'hyprland/systems'
• Added input 'hyprland/nixpkgs':
    'github:NixOS/nixpkgs/c6245e83d836d0433170a16eb185cefe0572f8b8?narHash=sha256-G/WVghka6c4bAzMhTwT2vjLccg/awmHkdKSd2JrycLc%3D' (2025-12-18)
• Added input 'hyprland/pre-commit-hooks':
    'github:cachix/git-hooks.nix/b68b780b69702a090c8bb1b973bab13756cc7a27?narHash=sha256-t3T/xm8zstHRLx%2BpIHxVpQTiySbKqcQbK%2Br%2B01XVKc0%3D' (2025-12-16)
• Added input 'hyprland/pre-commit-hooks/flake-compat':
    'github:edolstra/flake-compat/f387cd2afec9419c8ee37694406ca490c3f34ee5?narHash=sha256-XKUZz9zewJNUj46b4AJdiRZJAvSZ0Dqj2BNfXvFlJC4%3D' (2025-10-27)
• Added input 'hyprland/pre-commit-hooks/gitignore':
    'github:hercules-ci/gitignore.nix/637db329424fd7e46cf4185293b9cc8c88c95394?narHash=sha256-HG2cCnktfHsKV0s4XW83gU3F57gaTljL9KNSuG6bnQs%3D' (2024-02-28)
• Added input 'hyprland/pre-commit-hooks/gitignore/nixpkgs':
    follows 'hyprland/pre-commit-hooks/nixpkgs'
• Added input 'hyprland/pre-commit-hooks/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/systems':
    'github:nix-systems/default-linux/31732fcf5e8fea42e59c2488ad31a0e651500f68?narHash=sha256-12tWmuL2zgBgZkdoB6qXZsgJEH9LR3oUgpaQq2RbI80%3D' (2023-07-14)
• Added input 'hyprland/xdph':
    'github:hyprwm/xdg-desktop-portal-hyprland/4b8801228ff958d028f588f0c2b911dbf32297f9?narHash=sha256-xzjC1CV3%2BwpUQKNF%2BGnadnkeGUCJX%2BvgaWIZsnz9tzI%3D' (2025-10-25)
• Added input 'hyprland/xdph/hyprland-protocols':
    follows 'hyprland/hyprland-protocols'
• Added input 'hyprland/xdph/hyprlang':
    follows 'hyprland/hyprlang'
• Added input 'hyprland/xdph/hyprutils':
    follows 'hyprland/hyprutils'
• Added input 'hyprland/xdph/hyprwayland-scanner':
    follows 'hyprland/hyprwayland-scanner'
• Added input 'hyprland/xdph/nixpkgs':
    follows 'hyprland/nixpkgs'
• Added input 'hyprland/xdph/systems':
    follows 'hyprland/systems'
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/a6531044f6d0bef691ea18d4d4ce44d0daa6e816?narHash=sha256-3xY8CZ4rSnQ0NqGhMKAy5vgC%2B2IVK0NoVEzDoOh4DA4%3D' (2025-12-21)
copying channel...
building the flake in path:/mnt/etc/nixos?lastModified=1766420290&narHash=sha256-OYszdfaml4ojqpo7D020/SwCaaXKvzXL0DihvxhRRm4%3D...
nix: ../flake.cc:37: nix::StorePath nix::flake::copyInputToStore(nix::EvalState&, nix::fetchers::Input&, const nix::fetchers::Input&, nix::ref<nix::SourceAccessor>): Assertion `!originalInput.getNarHash() || storePath == originalInput.computeStorePath(*state.store)' failed.
/run/current-system/sw/bin/nixos-install: line 226:  1663 Aborted                    (core dumped) nix "${flakeFlags[@]}" build "$flake#$flakeAttr.config.system.build.toplevel" --store "$mountPoint" --extra-substituters "$sub" "${verbosity[@]}" "${extraBuildFlags[@]}" "${lockFlags[@]}" --out-link "$outLink"
```