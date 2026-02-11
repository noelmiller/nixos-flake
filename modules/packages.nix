{ config, pkgs, ... }:

{
  # common packages
  environment.systemPackages = with pkgs; [
    discord
    element-desktop
    google-chrome
    spotify
    yubioath-flutter
  ];

  # install and configure 1password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "noel" ];
  };
}
