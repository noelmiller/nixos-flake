{ config, pkgs, lib, ... }:

{
  # enable nix flakes feature
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # enable smart card and yubikey support
  services.pcscd.enable = true;

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
  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${config.networking.hostName}";
      update = "nix flake update --flake /home/noel/repos/nixos";
    };
  };

  # define a user account.
  users.users.noel = {
    isNormalUser = true;
    description = "Noel Miller";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
    ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = lib.mkDefault true;

  # install and configure git
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Noel Miller";
        email = "noel@noelmiller.dev";
      };
    init.defaultBranch = "main";
    };
  };

  # core programs
  environment.systemPackages = with pkgs; [
    chezmoi
    fastfetch
    gh
    tree
    vim
  ];
}
