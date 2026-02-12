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
      deploy = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      update = "nix flake update --flake /home/noel/repos/nixos";
      full-upgrade = "nix flake update --flake /home/noel/repos/nixos --commit-lock-file && sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      clean = "sudo nix-collect-garbage -d";
    };
  };

  # Git configuration
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
