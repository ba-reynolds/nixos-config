{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/common.nix
  ];

  networking.hostName = "bau-desktop";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 3923 ];   # allow port for copypart

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/4cd35ca3-7bda-492d-b233-d572cfc5d837";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems."/mnt/anm" = {
    device = "/dev/disk/by-uuid/6ca6163e-b245-460c-819d-7ca4ce3c0f29";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # swap file
  swapDevices = [ { device = "/var/lib/swapfile"; size = 8192; } ];
  
  # enable gnome virtual file system for trash backup
  services.gvfs.enable = true;

  # Optional: For better Bluetooth management (GUI)
  services.blueman.enable = true;

  # auto login
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };
  system.stateVersion = "25.11"; 
}