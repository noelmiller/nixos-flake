{ config, pkgs, ... }:

{
  # enable steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # enable mangohud
  programs.mangohud = {
    enable = true;
  };

  # enable gamescope
  programs.gamescope = {
    enable = true;
  };

  # enable gamemode
  programs.gamemode.enable = true;
}
