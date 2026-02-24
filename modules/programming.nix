{ pkgs, ... }:

{
  # install programming tools
  environment.systemPackages = with pkgs; [
    android-tools
    claude-code
    devcontainer
    devenv
    flatpak-builder
    github-copilot-cli
    kubectl
    kubernetes-helm
    lazygit
    marksman
    minikube
    nil # used for nix language server
    nixd # used for nix language server
    wget
    zed-editor
  ];
}
