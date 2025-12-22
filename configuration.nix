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