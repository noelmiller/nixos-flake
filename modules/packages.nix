{
  pkgs,
  # nixpkgs-calibre,
  features ? { },
  lib,
  config,
  ...
}:

let
  f = features;

  ## Example for pinning a package
  #  pkgs-calibre = import nixpkgs-calibre {
  #    inherit (pkgs) system;
  #    config.allowUnfree = true;
  #  };

  # Custom scrcpy with hardware acceleration (fixes ghost window)
  scrcpy-hw = pkgs.scrcpy.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/scrcpy --add-flags "--render-driver=opengl"
    '';
  });

  explicitPackages = lib.flatten [

    # ── Common ────────────────────────────────────────────────────────────
    (with pkgs; [
      dig
      fastfetch
      nmap
      psmisc
      nvd
      tree
      vim
      wget
    ])

    # ── Packages ──────────────────────────────────────────────────────────
    (with pkgs; [
      brave
      calibre
      discord
      element-desktop
      ente-desktop
      proton-vpn
      signal-desktop
      slack
      spotify
      vlc
      yubioath-flutter
    ])

    ## Example for pinning a package
    # lib.optionals (f.calibre or false) [ pkgs-calibre.calibre ]

    # ── Programming ───────────────────────────────────────────────────────
    (lib.optionals (f.programming or false) (
      with pkgs;
      [
        android-tools
        argocd
        claude-code
        claude-desktop-fhs
        flatpak-builder
        gemini-cli
        gh
        kompose
        kubectl
        kubernetes-helm
        minikube
        nil
        nixd
        zed-editor
      ]
    ))

    # ── Gaming ────────────────────────────────────────────────────────────
    (lib.optionals (f.gaming or false) (
      with pkgs;
      [
        jq
        protonplus
      ]
    ))

    # ── Video Editing ─────────────────────────────────────────────────────
    (lib.optionals (f.video or false) (
      with pkgs;
      [
        davinci-resolve-studio
        scrcpy-hw
        v4l-utils
      ]
    ))

    # ── Containers ────────────────────────────────────────────────────────
    (lib.optionals (f.containers or false) (with pkgs; [ distrobox ]))

    # ── Virtualisation ────────────────────────────────────────────────────
    (lib.optionals (f.virtualisation or false) (with pkgs; [ virt-manager ]))

    # ── Flatpak ───────────────────────────────────────────────────────────
    (lib.optionals (f.flatpak or false) (with pkgs; [ bazaar ]))

  ];

in
{
  options.my.explicitPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Packages explicitly declared in packages.nix (excludes transitive deps).";
  };

  config = {
    my.explicitPackages = explicitPackages;

    environment.systemPackages = explicitPackages;

    # ── 1Password ────────────────────────────────────────────────────────
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "noel" ];
    };

    # ── Brave / Chromium ─────────────────────────────────────────────────
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

    environment.etc."brave/policies/managed/policies.json" = {
      text = builtins.toJSON (import ./brave-policies.nix);
    };

    # ── Containers ───────────────────────────────────────────────────────
    virtualisation.docker.enable = f.containers or false;
    virtualisation.podman = lib.mkIf (f.containers or false) {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    users.users.noel.extraGroups =
      lib.optionals (f.containers or false) [ "docker" ]
      ++ lib.optionals (f.virtualisation or false) [ "libvirtd" ];

    # ── Virtualisation ───────────────────────────────────────────────────
    virtualisation.libvirtd = lib.mkIf (f.virtualisation or false) {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    # ── Flatpak ──────────────────────────────────────────────────────────
    services.flatpak.enable = f.flatpak or false;

    # ── Gaming ───────────────────────────────────────────────────────────
    programs.steam = lib.mkIf (f.gaming or false) {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    programs.gamescope.enable = f.gaming or false;
    programs.gamemode.enable = f.gaming or false;
    programs.zwift = lib.mkIf (f.zwift or false) {
      enable = true;
      containerTool = "podman";
    };

    hardware.opentabletdriver.enable = (f.gaming or false);
    hardware.uinput.enable = (f.gaming or false);

    # ── Tailscale ───────────────────────────────────────────────────────────
    services.tailscale.enable = f.tailscale or false;

    # ── Video Editing ─────────────────────────────────────────────────────
    hardware.graphics.extraPackages = lib.optionals (f.video or false) [
      pkgs.rocmPackages.clr.icd
    ];
    hardware.amdgpu.opencl.enable = f.video or false;
    boot.initrd.kernelModules = lib.optionals (f.video or false) [ "amdgpu" ];
    boot.extraModulePackages = lib.optionals (f.video or false) (
      with config.boot.kernelPackages; [ v4l2loopback ]
    );

    # ── Kernel Modules ─────────────────────────────────────────────────────
    boot.kernelModules =
      # needed for opentabletdriver
      lib.optionals (f.gaming or false) [ "uinput" ]
      # needed for obs virtual camera
      ++ lib.optionals (f.video or false) [ "v4l2loopback" ];
    boot.extraModprobeConfig = lib.mkIf (f.video or false) ''
      options v4l2loopback devices=1 video_nr=10 card_label="Virtual Camera" exclusive_caps=1
    '';
  };
}
