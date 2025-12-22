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
  };
}
