{ pkgs, ... }:
{
  time.timeZone = "America/Argentina/Buenos_Aires";
  console.keyMap = "la-latin1";
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.steam.enable = true;
  programs.hyprland.enable = true;
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.hyprland}/bin/Hyprland";
      user = "bau";
    };
  };

  users.users.bau = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [ vim wget git alsa-utils ];
}
