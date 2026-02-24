{ pkgs, email, ... }:

{
  home.stateVersion = "25.11";

  # user-specific packages
  home.packages = with pkgs; [
    bat
    carapace
    devcontainer
    devenv
    fd
    lazygit
    ripgrep
    zoxide
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
      set fish_greeting
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
      lg = {
        body = ''
          lazygit $argv[1]
        '';
      };
    };
  };

  # git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Noel Miller";
        email = email;
        init.defaultBranch = "main";
      };
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
