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
    ];

  networking.hostName = "macbook"; # Define your hostname.

  # enable camera for 2015 macbook pro
  hardware.facetimehd.enable = true;

  # fix issues with sleep on 2015 macbook pro
  powerManagement = {
    powerDownCommands = ''
      echo "DEBUG: Powering down - Unloading modules..." >> /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe -r -f facetimehd 2>&1 | tee -a /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe -r -f brcmfmac_wcc 2>&1 | tee -a /tmp/power-trace.log
    '';

    resumeCommands = ''
      echo "DEBUG: Resuming - Reloading modules..." >> /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe brcmfmac 2>&1 | tee -a /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe facetimehd 2>&1 | tee -a /tmp/power-trace.log
    '';
  };

  # enable redistributable firmware blobs for 2015 macbook pro
  hardware.enableRedistributableFirmware = true;

  # override enabled ssh by default
  services.openssh.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
