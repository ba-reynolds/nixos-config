{ pkgs, config, lib, ... }:

let
  # Use the shared path from our custom options
  dotfilesPath = config.internal.dotfilesPath;

  walBin = lib.getExe pkgs.pywal16;
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  hpprConf = "${dotfilesPath}/hypr/hyprpaper.conf";

  wpick = pkgs.writeShellApplication {
    name = "wpick";
    runtimeInputs = with pkgs; [
      pywal16
      hyprland
      procps
      coreutils
    ];

    text = ''
      IMG="$1"

      if [[ -z "$IMG" ]]; then
        echo "Usage: wpick /path/to/image"
        exit 1
      fi

      # 1. Generate colors with pywal
      "${walBin}" -i "$IMG" -n

      # 2. Overwrite the config file directly
      printf "preload = %s\nwallpaper = ,%s\n" "$IMG" "$IMG" > "${hpprConf}"

      # 3. Apply changes immediately via hyprctl
      ${hyprctl} hyprpaper preload "$IMG"
      ${hyprctl} hyprpaper wallpaper " ,$IMG"

      # 4. Refresh Waybar & Clean up RAM
      pkill -SIGUSR2 waybar || true
      ${hyprctl} hyprpaper unload all
    '';
  };
in
{
  config = {
    programs.pywal = {
      enable = true;
      package = pkgs.pywal16;
    };

    home.packages = [ wpick ];

    xdg.desktopEntries."wpick" = {
      name = "Set as Wallpaper";
      # Use %f for a single file, but Nautilus sometimes prefers %u (URL)
      # Adding 'NoDisplay=false' ensures it isn't hidden by the DE
      exec = "${lib.getExe wpick} %f"; 
      icon = "image-x-generic";
      mimeType = [ "image/jpeg" "image/png" "image/gif" "image/webp" ];
      categories = [ "Utility" ];
      settings = {
        NoDisplay = "false";
      };
    };
  };
}