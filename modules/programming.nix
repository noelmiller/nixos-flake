{ config, pkgs, ... }:

{
  # install programming tools
  environment.systemPackages = with pkgs; [
    android-tools
    devenv
    flatpak-builder
    github-copilot-cli
    lazygit
    marksman
    vscode
  ];

  # install and configure emacs
  services.emacs = {
    enable = true;
    package = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages (
      epkgs: [ epkgs.vterm ]
    );
    defaultEditor = true;
  };
}
