{ pkgs, nixpkgs-zed, ... }:

let
  pkgs-zed = import nixpkgs-zed {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

in
{
  # install programming tools
  environment.systemPackages = with pkgs; [
    android-tools
    argocd
    claude-code
    flatpak-builder
    gemini-cli
    gh
    kompose
    kubectl
    kubernetes-helm
    minikube
    nil # used for nix language server
    nixd # used for nix language server
    pkgs-zed.zed-editor # override broken zed build
  ];
}
