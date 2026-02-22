{ config, pkgs, osConfig, ... }:

{
  home.username = "noel";
  home.homeDirectory = "/home/noel";
  home.stateVersion = "25.11";

  imports = [
    ./modules/home/firefox.nix
  ];

  # user-specific packages
  home.packages = with pkgs; [
    carapace
    starship
  ];

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  # fish shell configuration
  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense'
    '';
    interactiveShellInit = ''
      carapace _carapace | source
    '';

    functions = {
      new-rust = {
        body = ''
          if test -n "$argv[1]"
            git clone --depth 1 https://github.com/noelmiller/rust-template.git $argv[1]
            and cd $argv[1]
            and rm -rf .git
            and direnv allow
            echo "Successfully initialized $argv[1] from template."
          else
            echo "Error: Please provide a project name."
            return 1
          end
        '';
      };
    };
    
    shellAbbrs = {
      deploy = "sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      update = "nix flake update --flake /home/noel/repos/nixos";
      full-upgrade = "nix flake update --flake /home/noel/repos/nixos && sudo nixos-rebuild switch --flake /home/noel/repos/nixos#${osConfig.networking.hostName}";
      clean = "sudo nix-collect-garbage -d";
    };
  };

  # git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Noel Miller";
        email = "noel@noelmiller.dev";
        init.defaultBranch = "main";
      };
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
