{ config, ... }:

{
  programs.fish.shellAbbrs = {
    update = "nix flake update --flake /home/noel/repos/nixos";
    check-packages = "/home/noel/repos/nixos/check-packages.sh";
    check-deploy = "nixos-rebuild dry-build --flake /home/noel/repos/nixos#${config.networking.hostName}";
    deploy = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${config.networking.hostName}";
    clean = "sudo nix-collect-garbage -d";
  };
}
