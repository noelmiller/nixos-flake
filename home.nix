{ config, pkgs, osConfig, ... }:

{
  home.username = "noel";
  home.homeDirectory = "/home/noel";
  home.stateVersion = "25.11";

  imports = [
    ./modules/home/firefox.nix
  ];

  # user-specific packages
  home.packages = with pkgs; [
  ];

  # fish shell configuration
  programs.fish = {
    enable = true;
    shellAbbrs = {
      deploy = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      update = "nix flake update --flake /home/noel/repos/nixos";
      full-upgrade = "nix flake update --flake /home/noel/repos/nixos --commit-lock-file && sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      clean = "sudo nix-collect-garbage -d";
    };
  };

  # git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Noel Miller";
        email = "noel@noelmiller.dev";
        init.defaultBranch = "main";
      };
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
