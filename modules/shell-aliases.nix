{ config, ... }:

{
  programs.fish.shellAbbrs = {
    deploy = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${config.networking.hostName}";
    update = "nix flake update --flake /home/noel/repos/nixos";
    full-upgrade = "nix flake update --flake /home/noel/repos/nixos && sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${config.networking.hostName}";
    clean = "sudo nix-collect-garbage -d";
  };
}
