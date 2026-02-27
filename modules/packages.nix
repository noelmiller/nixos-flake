{ pkgs, nixpkgs-calibre, ... }:

# override for broken calibre package
let
  pkgs-calibre = import nixpkgs-calibre {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

in
{
  # common packages
  environment.systemPackages = with pkgs; [
    brave
    pkgs-calibre.calibre # override for broken calibre package
    discord
    element-desktop
    ente-desktop
    protonvpn-gui
    signal-desktop
    slack
    spotify
    vlc
    yubioath-flutter
  ];

  # install and configure 1password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "noel" ];
  };

  # brave configuration
  programs.chromium = {
    enable = true;
    extensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "dbepggeogbaibhgnhhndojpepiihcmeb" # Vimium
      "lcbjdhceifofjlpecfpeimnnphbcjgnc" # xBrowserSync
    ];
  };

  # reference the external policy for brave

  environment.etc."brave/policies/managed/policies.json" = {
    text = builtins.toJSON (import ./brave-policies.nix);
  };
}
