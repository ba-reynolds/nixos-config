{ config, lib, pkgs, ... }:
# https://discuss.kde.org/t/i-cant-fix-caps-lock-delay-in-kde-neon/15915/7
# For some reason setting a symlink just breaks the whole fucking system but
# letting nix take care of this seems to work just fine
let
  cfg = config.modules.fix-capslock;
in {
  options.modules.fix-capslock = {
    enable = lib.mkEnableOption "Custom XKB Caps Lock fix";
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/xkb/symbols/custom".text = ''
      hidden partial modifier_keys
      xkb_symbols "caps_lock_instant" {
        key <CAPS> {
          type="ALPHABETIC",
          repeat=No,
          symbols[Group1] = [ Caps_Lock, Caps_Lock ],
          actions[Group1] = [ LockMods(modifiers=Lock),
            LockMods(modifiers=Shift+Lock,affect=unlock) ]
        };
      };
    '';

    home.file.".config/xkb/rules/evdev".text = ''
      ! option                  = symbols
        custom:caps_lock_instant = +custom(caps_lock_instant)

      ! include %S/evdev
    '';
  };
}