{ config, ... }:

{
  programs.fish.shellAbbrs = {
    update = "nix flake update --flake /home/noel/repos/nixos";
    check-packages = "nix run nixpkgs#python3 -- /home/noel/repos/nixos/check-packages.py";
    check-deploy = "nixos-rebuild dry-build --flake /home/noel/repos/nixos#${config.networking.hostName}";
    deploy = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${config.networking.hostName}";
    clean = "sudo nix-collect-garbage -d";
  };
}
