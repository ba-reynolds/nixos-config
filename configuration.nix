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

  time.timeZone = "America/Argentina/Buenos_Aires";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "la-latin1";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Save space by hard-linking identical files
  nix.settings.auto-optimise-store = false;

  # Auto-login
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = "bau";
      };
    };
  };

  # Audio with PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # XDG Portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.bau = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # Enable 'sudo' and NetworkManager for the user.
  };

  # Allow non-free packages
  nixpkgs.config.allowUnfree = true;
  programs.hyprland.enable = true;

  # Minimal system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    alsa-utils
  ];

  fileSystems."/mnt/anm" = {
    device = "/dev/disk/by-uuid/2A2244272243F67B";
    # fsType = "ext4"; # Replace with your FSTYPE (e.g. "ntfs", "exfat", "vfat")
    fsType = "ntfs-3g"; # Use ntfs-3g for better read/write support
    options = [ 
        "nofail" 
        "uid=1000" # Maps the drive ownership to your user (usually 1000)
        "rw"       # Mount as read-write
      ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/C66AF9386AF925B9";
    # fsType = "ext4"; # Replace with your FSTYPE (e.g. "ntfs", "exfat", "vfat")
    fsType = "ntfs-3g"; # Use ntfs-3g for better read/write support
    options = [ 
        "nofail" 
        "uid=1000" # Maps the drive ownership to your user (usually 1000)
        "rw"       # Mount as read-write
      ];
  };

  boot.supportedFilesystems = [ "ntfs" "exfat" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11"; # Did you read the comment?
}