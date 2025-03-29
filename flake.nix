{
  description = "Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # see overlay in overlays/default.nix
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-24.11-darwin";
    nixpkgs-darwin-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-darwin-unstable = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-darwin-unstable";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    # automatically update Homebrew, installed via declarative tap management of nix-homebrew
    homebrew-domt4-autoupdate = {
      url = "github:DomT4/homebrew-autoupdate";
      flake = false;
    };
    # Spotube
    homebrew-spotube = {
      url = "github:KRTirtho/homebrew-apps";
      flake = false;
    };
    # sshfs-mac
    homebrew-fuse = {
      url = "github:gromgit/homebrew-fuse";
      flake = false;
    };

    home-manager = {
      # url = "github:nix-community/home-manager/release-24.11"; # gets timeouts
      url = "https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-darwin = {
      # url = "github:nix-community/home-manager/release-24.11"; # gets timeouts
      url = "https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    home-manager-darwin-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-darwin-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/nur"; # Nix User Repository: User contributed nix packages

    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-darwin,
      nixpkgs-darwin-unstable,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-domt4-autoupdate,
      homebrew-spotube,
      homebrew-fuse,
      nix-darwin,
      nix-darwin-unstable,
      home-manager,
      home-manager-darwin,
      home-manager-darwin-unstable,
      agenix,
      nix-index-database,
      nur,
      deploy-rs,
      ...
    }@inputs:
    let
      machinesSensitiveVars = builtins.fromJSON (builtins.readFile "${self}/machinesSensitiveVars.json");

      homeManagerCfg = userPackages: extraImports: {
        home-manager = {
          useGlobalPkgs = false; # makes hm use nixos's pkgs value
          useUserPackages = userPackages;
          extraSpecialArgs = { inherit inputs; }; # allows access to flake inputs in hm modules
          users.jakob =
            { config, pkgs, ... }:
            {
              nixpkgs.overlays = [
                inputs.nur.overlay
              ];
              #home.homeDirectory = nixpkgs-darwin.lib.mkForce "/Users/jakob";
              shell = pkgs.zsh;

              imports = [
                inputs.nix-index-database.hmModules.nix-index
                inputs.agenix.homeManagerModules.default
                inputs.nixpkgs-darwin
                ./users/jakob/dots.nix
              ];
            };

          backupFileExtension = "bak";
        };
      };
    in
    {
      darwinConfigurations."MainDev" = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit inputs;
          inherit self;
          inherit machinesSensitiveVars;
        };
        modules = [
          inputs.agenix.darwinModules.default
          inputs.home-manager-darwin.darwinModules.home-manager
          (inputs.nixpkgs-darwin.lib.attrsets.recursiveUpdate (homeManagerCfg true [ ]) {
            home-manager.users.jakob.home.homeDirectory = inputs.nixpkgs-darwin.lib.mkForce "/Users/jakob";
            home-manager.users.jakob.home.stateVersion = "24.11";
          })
          nix-homebrew.darwinModules.nix-homebrew
          ./machines/darwin
          ./machines/darwin/MainDev
          # ./modules/tailscale
        ];
      };

      deploy.nodes = {
        MainServer = {
          hostname = machinesSensitiveVars.MainServer.ipAddress;
          profiles.system = {
            sshUser = "jakob";
            user = machinesSensitiveVars.MainServer.username;
            sshOpts = [
              "-p"
              machinesSensitiveVars.MainServer.sshPort
            ];
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
            inherit self;
            inherit machinesSensitiveVars;
            vars = import ./machines/nixos/MainServer/vars.nix;
          };
          modules = [
            # Base
            agenix.nixosModules.default
            ./modules/zfs-root
            ./modules/tailscale
            ./modules/mergerfs-uncache
            ./modules/podman

            # Imports
            ./machines/nixos
            ./machines/nixos/MainServer

            # Services
            ./services/traefik
            ./services/monitoring
            ./services/homepage

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
                ./users/jakob/syncthing.nix
              ];
              home-manager.backupFileExtension = "bak";
            }
          ];
        };
      };
    };
}
