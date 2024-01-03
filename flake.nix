{
  description = "Configuration for MacOS and NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/nur"; # Nix User Repository: User contributed nix packages

    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self,
              nixpkgs,
              nix-darwin,
              home-manager,
              nix-index-database,
              agenix,
              deploy-rs,
              nur,
              ... }@inputs:
 {
    darwinConfigurations."MainDev" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {
        inherit inputs;
        sectrets = import ./sectrets;
      };
      modules = [
        agenix.darwinModules.default
        ./machines/darwin
        ./machines/darwin/MainDev
        # ./modules/tailscale
        ];
      };

    deploy.nodes = {
      MainServer = {
        hostname = secrets.MainServer_ipAddress.path;
        profiles.system = {
          sshUser = "jakob";
          user = secrets.MainServer_username.path;
          sshOpts = [ "-p" secrets.MainServer_sshPort.path ];
          remoteBuild = true;
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.MainServer;
        };
      };
    };

    nixosConfigurations = {
      MainServer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          vars = import ./machines/nixos/MainServer/vars.nix;
          sectrets = import ./sectrets;
        };
        modules = [
            # Base
            ./modules/zfs-root
            ./modules/tailscale
            ./modules/mergerfs-uncache

            # Imports
            ./machines/nixos
            ./machines/nixos/MainServer
            agenix.nixosModules.default

            # Services
            ./services/monitoring

            # Users
            ./users/jakob
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = false;
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.users.jakob.imports = [
                  agenix.homeManagerModules.default
                  nix-index-database.hmModules.nix-index
                  ./users/jakob/dots.nix
                ];
              home-manager.backupFileExtension = "bak";
            }
        ];
      };
    };
  };
}
