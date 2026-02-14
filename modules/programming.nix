{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    flatpak-builder
    unstable.github-copilot-cli
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
