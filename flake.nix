{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    zwift.url = "github:netbrain/zwift";
    claude-desktop.url = "github:aaddrick/claude-desktop-debian";
    ## Example for pinning a package
    #nixpkgs-calibre.url = "github:NixOS/nixpkgs/e75cdcb2b4b3698c61993b85440ee97761dbcc88";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      zwift,
      claude-desktop,
      ## Example for pinning a package
      # nixpkgs-calibre,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      mkSystem =
        host: username: email: features:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              ## Example for pinning a package
              # nixpkgs-calibre
              features
              ;
          };
          modules = [
            ./hosts/${host}/configuration.nix
            home-manager.nixosModules.home-manager
            zwift.nixosModules.default
            ./modules/packages.nix
            {
              nixpkgs.overlays = [ overlay-stable claude-desktop.overlays.default ];
              nixpkgs.config.allowUnfree = true;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${username} = {
                imports = [ ./home.nix ];
                home.username = username;
                home.homeDirectory = "/home/${username}";
              };
              home-manager.extraSpecialArgs = {
                inherit inputs email;
              };
            }
          ];
        };

      mkHome =
        username: email:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay-stable ];
          };
          extraSpecialArgs = { inherit email; };
          modules = [
            ./home.nix
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        desktop = mkSystem "desktop" "noel" "noel@noelmiller.dev" {
          # Example for pinning a package
          # calibre = true;
          containers = true;
          flatpak = true;
          gaming = true;
          programming = true;
          video = true;
          virtualisation = true;
          zwift = true;
        };

        macbook = mkSystem "macbook" "noel" "noel@noelmiller.dev" {
          # Example for pinning a package
          # calibre = true;
          containers = true;
          flatpak = true;
          programming = true;
          tailscale = true;
        };
      };

      homeConfigurations = {
        "noel" = mkHome "noel" "noel@noelmiller.dev";
        "nomiller" = mkHome "nomiller" "nomiller@redhat.com";
      };
    };
}
