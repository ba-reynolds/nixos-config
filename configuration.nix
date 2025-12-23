{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      # ./modules/fix-headphones.nix
    ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # services.unmuteHeadphones.enable = true;

  networking.hostName = "bau-pc"; 
  networking.networkmanager.enable = true;
  services.getty.autologinUser = "bau";
  time.timeZone = "America/Argentina/Buenos_Aires";

  hardware.alsa.enablePersistence = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
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
    btop
    mpv
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11"; # Did you read the comment?
}