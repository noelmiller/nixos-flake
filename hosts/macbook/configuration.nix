{ config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  # bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "macbook"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # enable networking
  networking.networkmanager.enable = true;

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

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = false;

  # enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # enable CUPS to print documents.
  services.printing.enable = true;

  # enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # enable fish shell
  programs.fish.enable = true;

  # define a user account.
  users.users.noel = {
    isNormalUser = true;
    description = "Noel Miller";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
    shell = pkgs.fish;
    packages = with pkgs; [
    ];
  };


  # enable camera for macbook pro
  hardware.facetimehd.enable = true;

  # enable bluetooth
  hardware.bluetooth.enable = true;
  services.pcscd.enable = true;

  powerManagement = {
    powerDownCommands = ''
      echo "DEBUG: Powering down - Unloading modules..." >> /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe -r -f facetimehd 2>&1 | tee -a /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe -r -f brcmfmac_wcc 2>&1 | tee -a /tmp/power-trace.log
    '';

    resumeCommands = ''
      echo "DEBUG: Resuming - Reloading modules..." >> /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe brcmfmac 2>&1 | tee -a /tmp/power-trace.log
      ${pkgs.kmod}/bin/modprobe facetimehd 2>&1 | tee -a /tmp/power-trace.log
    '';
  };
  hardware.enableRedistributableFirmware = true;


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

  # install and configure 1password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "noel" ];
  };

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # list packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bazaar
    chezmoi
    discord
    distrobox
    element-desktop
    fastfetch
    flatpak-builder
    gh
    google-chrome
    lazygit
    spotify
    tree
    vim
    virt-manager
    yubioath-flutter
  ];

  # install and configure emacs
  services.emacs = {
    enable = true;
    package = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages (
      epkgs: [ epkgs.vterm ]
    );
    defaultEditor = true;
  };

  # install and configure flatpak
  services.flatpak.enable = true;

  # enable docker
  virtualisation.docker = {
    enable = true;
  };

  # enable podman 
  virtualisation.podman = {
    enable = true;
    # Create the default bridge network for podman
    defaultNetwork.settings.dns_enabled = true;
  };

  # enable virtualization
  virtualisation.libvirtd = {
  enable = true;
  qemu = {
    package = pkgs.qemu_kvm;
    runAsRoot = true;
    swtpm.enable = true;
  };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
