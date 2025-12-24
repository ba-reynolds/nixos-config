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

  # Font
  fonts.packages = with pkgs; [
    nerd-fonts.sauce-code-pro
  ];
  
  # Minimal system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    alsa-utils
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11"; # Did you read the comment?
}