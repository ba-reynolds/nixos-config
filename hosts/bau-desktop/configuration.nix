{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/common.nix
  ];

  networking.hostName = "bau-desktop";
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/mnt/anm" = {
    device = "/dev/disk/by-uuid/2A2244272243F67B";
    fsType = "ntfs-3g";
    options = [ "nofail" "uid=1000" "rw" ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/C66AF9386AF925B9";
    fsType = "ntfs-3g";
    options = [ "nofail" "uid=1000" "rw" ];
  };

  swapDevices = [ { device = "/var/lib/swapfile"; size = 8192; } ];
  
  system.stateVersion = "25.11"; 
}