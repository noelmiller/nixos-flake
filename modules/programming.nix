{ pkgs, ... }:

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
    zed-editor
  ];
}
