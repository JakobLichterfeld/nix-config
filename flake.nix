{
  description = "Configuration for MacOS and NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
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
    let
      machines = import ./machines.nix;
    in {
    darwinConfigurations."MainDev" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {
        inherit inputs machines;
      };
      modules = [
        agenix.darwinModules.default
        ./machines/darwin
        ./machines/darwin/MainDev
        ./modules/tailscale
        ];
      };

    # deploy.nodes = {
    #   emily = {
    #     hostname = machines.emily.address;
    #     profiles.system = {
    #       sshUser = "jakob";
    #       user = "root";
    #       sshOpts = [ "-p" "69" ];
    #       remoteBuild = true;
    #       path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.emily;
    #     };
    #   };
    #   spencer = {
    #     hostname = machines.spencer.address;
    #     profiles.system = {
    #       sshUser = "notthebee";
    #       user = "root";
    #       sshOpts = [ "-p" "69" ];
    #       remoteBuild = true;
    #       path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.spencer;
    #     };
    #   };
    # };

    # nixosConfigurations = {
    #   spencer = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     specialArgs = {
    #       inherit inputs machines;
    #       vars = import ./machines/nixos/spencer/vars.nix;
    #     };
    #     modules = [
    #       # Base configuration and modules
    #         ./modules/email
    #         ./modules/wireguard
    #         ./modules/tg-notify
    #         ./modules/notthebe.ee

    #         # Import the machine config + secrets
    #         ./machines/nixos
    #         ./machines/nixos/spencer
    #         ./secrets
    #         agenix.nixosModules.default

    #         # User-specific configurations
    #         ./users/notthebee
    #         home-manager.nixosModules.home-manager
    #         {
    #           home-manager.useGlobalPkgs = false; # makes hm use nixos's pkgs value
    #             home-manager.extraSpecialArgs = { inherit inputs machines; }; # allows access to flake inputs in hm modules
    #             home-manager.users.notthebee.imports = [
    #             agenix.homeManagerModules.default
    #             nix-index-database.hmModules.nix-index
    #             ./users/notthebee/dots.nix
    #             ];
    #           home-manager.backupFileExtension = "bak";
    #         }
    #     ];
    #   };

    #   emily = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     specialArgs = {
    #       inherit inputs machines;
    #       vars = import ./machines/nixos/emily/vars.nix;
    #     };
    #     modules = [
    #         # Base configuration and modules
    #         ./modules/aspm-tuning
    #         ./modules/zfs-root
    #         ./modules/email
    #         ./modules/tg-notify
    #         ./modules/podman
    #         ./modules/mover
    #         ./modules/motd
    #         ./modules/appdata-backup

    #         # Import the machine config + secrets
    #         ./machines/nixos
    #         ./machines/nixos/emily
    #         ./secrets
    #         agenix.nixosModules.default

    #         # Services and applications
    #         # ./services/invoiceninja
    #         # ./services/paperless-ngx
    #         # ./services/icloud-drive
    #         # ./services/traefik
    #         # ./services/deluge
    #         # ./services/arr
    #         # ./services/jellyfin
    #         # ./services/vaultwarden
    #         # ./services/monitoring
    #         # ./services/kiwix

    #         # User-specific configurations
    #         ./users/notthebee
    #         home-manager.nixosModules.home-manager
    #         {
    #           home-manager.useGlobalPkgs = false;
    #             home-manager.extraSpecialArgs = { inherit inputs machines; };
    #             home-manager.users.notthebee.imports = [
    #               agenix.homeManagerModules.default
    #               nix-index-database.hmModules.nix-index
    #               ./users/notthebee/dots.nix
    #             ];
    #           home-manager.backupFileExtension = "bak";
    #         }
    #     ];
    #   };
    # };
  };
}
