{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    flatpak-builder
    lazygit
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
