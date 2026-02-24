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

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      zwift,
      flox,
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

      overlay-flox = final: prev: {
        flox = flox.packages.${system}.default;
      };

      mkSystem =
        host: username:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/${host}/configuration.nix
            home-manager.nixosModules.home-manager
            zwift.nixosModules.default
            {
              nixpkgs.overlays = [
                overlay-stable
                overlay-flox
              ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${username} = {
                imports = [ ./home.nix ];
                home.username = username;
                home.homeDirectory = "/home/${username}";
              };
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };

      mkHome =
        username:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
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
        macbook = mkSystem "macbook" "noel";
        desktop = mkSystem "desktop" "noel";
      };

      homeConfigurations = {
        "noel" = mkHome "noel";
        "nomiller" = mkHome "nomiller";
      };
    };
}
