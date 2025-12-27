{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/wpick.nix
  ];

  # --- CUSTOM OPTIONS DEFINITION ---
  options.internal = {
    userName = lib.mkOption { 
      type = lib.types.str; 
      default = "bau"; 
    };
    homeDirectory = lib.mkOption { 
      type = lib.types.str; 
      default = "/home/${config.internal.userName}"; 
    };
    nixosConfigPath = lib.mkOption { 
      type = lib.types.str; 
      default = "${config.internal.homeDirectory}/nixos-config"; 
    };
    dotfilesPath = lib.mkOption { 
      type = lib.types.str; 
      default = "${config.internal.nixosConfigPath}/dotfiles"; 
    };
  };

  # --- CONFIGURATION ---
  config = {
    home.username      = config.internal.userName;
    home.homeDirectory = config.internal.homeDirectory;
    home.stateVersion   = "25.11";

    # allow apps to use our installed fonts
    fonts.fontconfig.enable = true;
    # use mako for notifications
    services.mako.enable = true;

    home.packages = with pkgs; [
      home-manager

      # apps
      firefox
      vscode
      anki-bin
      mpv
      spotify
      ffmpeg

      # terminal
      kitty
      tree
      bat
      btop
      neofetch
      wl-clipboard

      # ui & qol tools
      cliphist
      hyprpaper       # set wallpaper
      hyprshot        # take screenshot
      waybar
      pavucontrol     # ui when clicking gear icon in audio island, waybar
      rofi
      libnotify       # standard used for notifications
      nwg-displays    # ui to manage monitors

      # fonts
      nerd-fonts.code-new-roman
      nerd-fonts.sauce-code-pro
      nerd-fonts.symbols-only

      # --- Dolphin & File Management ---
      kdePackages.dolphin
      kdePackages.ark                   
      kdePackages.qtsvg                 
      kdePackages.kio-extras            
      kdePackages.ffmpegthumbs          
      kdePackages.kdegraphics-thumbnailers
    ];

    programs.git.enable = true;

    programs.bash = {
      enable = true;
      shellAliases = {
        nrs = "sudo nixos-rebuild switch --flake ${config.internal.nixosConfigPath}#bau-pc";
        hms = "home-manager switch --flake ${config.internal.nixosConfigPath}#bau-pc";
      };
      initExtra = ''
        export PS1='\[\e[38;5;76m\]\u\[\e[0m\] in \[\e[38;5;32m\]\w\[\e[0m\] \\$ '
        ns() {
          nix shell ''${@/#/nixpkgs#}
        }
      '';
    };

    xdg.terminal-exec = {
      enable = true;
      settings = {
        default = [ "kitty.desktop" ];
      };
    };

    # --- DOTFILES MANAGEMENT ---
    # All files are symlinked directly to the local dotfiles directory
    home.file = {
      ".vimrc".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/vim/.vimrc";
    };

    xdg.configFile = {
      "waybar".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/waybar";
      "kitty".source  = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/kitty";
      "rofi".source   = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/rofi";
      "mpv".source    = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/mpv";
      "hypr".source   = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/hypr";
    };
  };
}