{ config, pkgs, ... }:

{
  home.username = "noel";
  home.homeDirectory = "/home/noel";
  home.stateVersion = "25.11"; # Matches your flake input version

  # User-specific packages
  home.packages = with pkgs; [
  ];

  # Fish shell configuration
  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#\${config.networking.hostName}";
      update = "nix flake update --flake /home/noel/repos/nixos";
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Noel Miller";
    userEmail = "noel@noelmiller.dev";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.firefox = {
    enable = true;
    
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      
      # DISABLING AI INTEGRATIONS
      # This hits the system-level policy flags for AI features
      BrowserSettings = {
        # Disables the "AI Chat" sidebar feature and integration
        "browser.ml.enable" = { Value = false; Status = "locked"; };
        "browser.ml.chat.enabled" = { Value = false; Status = "locked"; };
        # Disables the AI-powered "Review Checker" (Fakespot)
        "browser.shopping.experience2023.enabled" = { Value = false; Status = "locked"; };
      };

      # EXTENSION INSTALLATION
      ExtensionSettings = {
        # uBlock Origin
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        # Dark Reader
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      SearchEngines = {
        Default = "DuckDuckGo";
      };
    };

    profiles.default = {
      settings = {
        # Redundant safety for AI features at the preference level
        "browser.ml.chat.enabled" = false;
        "browser.ml.enable" = false;
        "browser.shopping.experience2023.enabled" = false;
        
        # General clean up
        "extensions.pocket.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      };
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
