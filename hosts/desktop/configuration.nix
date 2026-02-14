{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../common/default.nix
      ../../modules/containers.nix
      ../../modules/flatpak.nix
      ../../modules/kde.nix
      ../../modules/packages.nix
      ../../modules/programming.nix
      ../../modules/virtualisation.nix
    ];

  networking.hostName = "desktop"; # Define your hostname.

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
