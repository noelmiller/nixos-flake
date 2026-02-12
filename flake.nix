{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }: {
    nixosConfigurations = {
      # This matches your 'macbook' directory
      macbook = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
          ./hosts/macbook/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.noel = import ./home.nix;
          }
        ];
      };

      # This matches your 'desktop' directory
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
          ./hosts/desktop/configuration.nix
             home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.noel = import ./home.nix;
          }
        ];
      };
    };
  };
}
