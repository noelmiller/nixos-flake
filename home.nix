{ config, pkgs, osConfig, ... }:

{
  home.username = "noel";
  home.homeDirectory = "/home/noel";
  home.stateVersion = "25.11"; # Matches your flake input version

  # User-specific packages
  home.packages = with pkgs; [
  ];

  # Fish shell configuration
  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      update = "nix flake update --flake /home/noel/repos/nixos";
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Noel Miller";
    userEmail = "noel@noelmiller.dev";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
