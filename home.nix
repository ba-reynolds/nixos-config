{ config, pkgs, ... }:
{
  home.username = "bau";
  home.stateVersion = "25.11";

  # Packages moved from configuration.nix
  home.packages = with pkgs; [
    firefox
    vscode
    anki-bin
    kitty
    bat
    btop
    mpv
    neofetch
    wl-clipboard
    tree
    hyprpaper
  ];

  programs.git = {
    enable = true;
    # Consider adding user config here:
    # userName = "Your Name";
    # userEmail = "your.email@example.com";
  };
  
  programs.rofi.enable = true;
  
  programs.pywal = {
    enable = true;
    package = pkgs.pywal16;
  };
  
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#bau-pc";
    };
    initExtra = ''
      export PS1='\[\e[38;5;76m\]\u\[\e[0m\] in \[\e[38;5;32m\]\w\[\e[0m\] \\$ '
      ns() {
        nix shell ''${@/#/nixpkgs#}
      }
    '';
  };

  xdg.configFile = {
    waybar.source = ./dotfiles/waybar;
    kitty.source = ./dotfiles/kitty;
    rofi.source = ./dotfiles/rofi;

  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}