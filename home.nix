{ config, pkgs, ... }:
{
  home.username = "bau";
  home.homeDirectory = "/home/bau";
  home.stateVersion = "25.11";
  programs.git.enable = true;
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "nixos-rebuild switch --flake /etc/nixos#bau-pc";
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
}
