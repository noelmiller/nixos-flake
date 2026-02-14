{ config, pkgs, scopebuddy, ... }:

{
  # enable steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # enable gamescope
  programs.gamescope = {
    enable = true;
  };

  # enable gamemode
  programs.gamemode.enable = true;

  # install gaming tools
  environment.systemPackages = with pkgs; [
    protonplus
    scopebuddy.packages.${pkgs.system}.default
    jq
  ];
}
