{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations = {
      # This matches your 'macbook' directory
      macbook = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux"; # Adjust to "aarch64-linux" if it's an ARM Mac/VM
        modules = [ 
          ./hosts/macbook/configuration.nix 
        ];
      };

      # This matches your 'desktop' directory
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
          ./hosts/desktop/configuration.nix 
        ];
      };
    };
  };
}
