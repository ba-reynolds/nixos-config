{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/home/wpick.nix
    ./modules/home/waybar-scripts.nix
    ./modules/home/fix-capslock.nix
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

    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    home.packages = with pkgs; [
      home-manager

      # apps
      firefox
      vscode
      anki-bin
      spotify
      ffmpeg
      qbittorrent
      nautilus
      copyparty
      google-chrome

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
      pulseaudio      # provides pactl, used to set volume in waybar
      rofi
      libnotify       # standard used for notifications
      nwg-displays    # ui to manage monitors
      playerctl       # manage song
      cava

      # fonts & icons
      nerd-fonts.code-new-roman
      nerd-fonts.sauce-code-pro
      nerd-fonts.symbols-only
      papirus-icon-theme
    ];

    # fix delay on capslock (simulate windos behavior)
    modules.fix-capslock.enable = true;

    # allow apps to use our installed fonts
    fonts.fontconfig.enable = true;

    # use mako for notifications
    services.mako.enable = true;
    # enable copyparty as a service
    systemd.user.services.copyparty = {
      Unit = {
        Description = "copyparty file server";
        After = [ "network.target" ];
      };

      Service = {
        # Use the binary from the package
        ExecStart = "${pkgs.copyparty}/bin/copyparty -c ${config.internal.dotfilesPath}/copyparty/copyparty.conf";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # --- Programs ---
    programs.git.enable = true;

    programs.mpv = {
      enable = true;
      scripts = with pkgs.mpvScripts; [
        autoload     # Automatically loads other images in the same folder
      ];
    };

    programs.bash = {
      enable = true;
      shellAliases = {
        nrs = "sudo nixos-rebuild switch --flake ${config.internal.nixosConfigPath}#";
        hms = "home-manager switch --flake ${config.internal.nixosConfigPath}#";
      };
      initExtra = ''
        export PS1='\[\e[38;5;76m\]\u\[\e[0m\] in \[\e[38;5;32m\]\w\[\e[0m\] \\$ '
        ns() {
          nix shell ''${@/#/nixpkgs#}
        }
      '';
    };

    # Set default gnome theme
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        icon-theme = "Papirus-Dark";
      };
    };


    # Some programs look for this to check what's our default terminal
    xdg.terminal-exec = {
      enable = true;
      settings = {
        default = [ "kitty.desktop" ];
      };
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # video
        "video/mp4" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-flv" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];
        "video/mpeg" = [ "mpv.desktop" ];
        "video/ogg" = [ "mpv.desktop" ];
        "video/avi" = [ "mpv.desktop" ];
        # image%h/.config/copyparty/copyparty.conf
        "image/jpeg" = [ "mpv.desktop" ];
        "image/png" = [ "mpv.desktop" ];
        "image/gif" = [ "mpv.desktop" ];
        "image/webp" = [ "mpv.desktop" ];
      };        
    };


    # --- DOTFILES MANAGEMENT ---
    # All files are symlinked directly to the local dotfiles directory
    # Nautilus is the exception because you have to do some very weird logic
    # ...bash too because I think nix adds some defaults into .bashrc so I don't want to mess with that
    home.file = {
      ".vimrc".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/vim/.vimrc";
      ".local/share/nautilus/scripts/Set as Wallpaper".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/nautilus/scripts/Set as Wallpaper";
      ".local/share/nautilus/scripts/Open in Kitty".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/nautilus/scripts/Open in Kitty";
    };
  
    xdg.dataFile = {
      "kio/servicemenus".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/kio";
    };

    # if dir exists then its alright
    # if it doesnt, nix creates a symlink to the store and you cannot write to it
    xdg.configFile = {
      #"copyparty/copyparty.conf".source   = config.lib.file.mkOutOfStoreSymlink .dotfiles/copyparty/copyparty.conf;
      "hypr".source   = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/hypr";
      "kitty".source  = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/kitty";
      "mako".source  = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/mako";
      "mpv".source  = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/mpv";
      "nautilus/scripts-accels".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/nautilus/scripts-accels";
      "rofi".source   = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/rofi";
      "Code/User/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/vscode/settings.json";
      "Code/User/keybindings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/vscode/keybindings.json";
      "waybar".source = config.lib.file.mkOutOfStoreSymlink "${config.internal.dotfilesPath}/waybar";
    };
  };
}
