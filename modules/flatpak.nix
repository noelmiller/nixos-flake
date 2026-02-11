{ config, pkgs, ... }:

{
  # install and configure flatpak
  services.flatpak.enable = true;

  environment.systemPackages = with pkgs; [
    bazaar
  ];
}
