{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    android-tools
    flatpak-builder
    github-copilot-cli
    lazygit
    marksman
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
