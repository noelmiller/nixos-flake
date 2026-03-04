{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/default.nix
    ../../modules/kde.nix
    ../../modules/packages.nix
  ];

  networking.hostName = "desktop"; # Define your hostname.

  # recommended for systems above 16GB of RAM and on a faster internet connection
  nix.settings.download-buffer-size = 524288000; # 500 MB

  # Additional data drives
  fileSystems."/mnt/nvme_2t" = {
    device = "/dev/disk/by-uuid/29482386-070a-495e-b66c-8f0be0a994fe";
    fsType = "btrfs";
  };

  fileSystems."/mnt/ssd_8t" = {
    device = "/dev/disk/by-uuid/3d4fecf4-5870-4132-a81d-b5feb4aa7371";
    fsType = "btrfs";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
