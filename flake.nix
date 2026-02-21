{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    zwift.url = "github:netbrain/zwift";
    flox.url = "github:flox/flox";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, zwift, flox, ... }@inputs:
    let
      system = "x86_64-linux";

      # Create an overlay to make stable packages available
      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      # Create an overlay to make flox-cli available
      overlay-flox = final: prev: {
        flox = flox.packages.${system}.default;
      };

      mkSystem = host:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/${host}/configuration.nix
            home-manager.nixosModules.home-manager
            zwift.nixosModules.default
            {
              nixpkgs.overlays = [ overlay-stable overlay-flox ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.noel = import ./home.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        macbook = mkSystem "macbook";
        desktop = mkSystem "desktop";
      };
    };
}
