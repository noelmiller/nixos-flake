{ config, pkgs, lib, ... }:

{
  # enable nix flakes feature
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # configure automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # add flox cache as a trusted substituter and public key
  nix.settings.trusted-substituters = [ "https://cache.flox.dev", "https://devenv.cachix.org" ];
  nix.settings.trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=", "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # enable smart card and yubikey support
  services.pcscd.enable = true;

  # Enable basic OpenGL hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Needed for 32-bit games/apps
  };

  # set your time zone.
  time.timeZone = "America/Chicago";

  # select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # enable fish shell
  programs.fish.enable = true;

  # define a user account.
  users.users.noel = {
    isNormalUser = true;
    description = "Noel Miller";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = lib.mkDefault true;

  # Nerd Fonts
  fonts.packages = builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  # core programs
  environment.systemPackages = with pkgs; [
    chezmoi
    dig
    fastfetch
    flox
    gh
    tree
    vim
  ];
}
