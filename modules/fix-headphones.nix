{ config, lib, pkgs, ... }:
{
  options.services.unmuteHeadphones.enable = lib.mkEnableOption
    "Unmute rear headphones at boot using ALSA";

  config = lib.mkIf config.services.unmuteHeadphones.enable {
    systemd.user.services.unmute-headphones = {
      description = "Unmute rear headphones";
      wantedBy = [ "default.target" ];
      after = [ "wireplumber.service" ];
      requires = [ "wireplumber.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c \
            "${pkgs.alsa-utils}/bin/amixer -c 2 set 'Auto-Mute Mode' Disabled && \
             ${pkgs.alsa-utils}/bin/amixer -c 2 set Front unmute"
        '';
      };
    };
  };
}