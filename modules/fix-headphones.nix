{ config, lib, pkgs, ... }:
{
  options.services.unmuteHeadphones.enable = lib.mkEnableOption
    "Unmute rear headphones at boot using ALSA";

  config = lib.mkIf config.services.unmuteHeadphones.enable {
    systemd.services.unmute-headphones = {
      description = "Unmute rear headphones";
      wantedBy = [ "multi-user.target" ];
      after = [ "sound.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c \
            "${pkgs.alsa-utils}/bin/amixer -c 1 set 'Auto-Mute Mode' Disabled && \
             ${pkgs.alsa-utils}/bin/amixer -c 1 set Front unmute"
        '';
      };
    };
  };
}
