{
  description = "Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs-darwin-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
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
    # TabbyML
    homebrew-tabbyml = {
      url = "github:TabbyML/homebrew-tabby";
      flake = false;
    };

    home-manager = {
      # url = "github:nix-community/home-manager/release-25.05"; # gets timeouts
      url = "https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-darwin = {
      # url = "github:nix-community/home-manager/release-25.05"; # gets timeouts
      url = "https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz";
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

    deploy-rs.url = "github:serokell/deploy-rs";

    teslamate = {
      url = "github:teslamate-org/teslamate?rev=92b504bf405b7238b13231869b6ef73c7564f520"; # v2.1.0
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spotblock = {
      url = "github:vincentkenny01/spotblock";
      flake = false;
    };
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
      deploy-rs,
      ...
    }@inputs:
    let
      machinesSensitiveVars = builtins.fromJSON (builtins.readFile "${self}/machinesSensitiveVars.json");

      manualSensitiveDarwin = import ./machines/darwin/manualSensitive.nix;
      manualSensitiveDarwinMainDev = import ./machines/darwin/MainDev/manualSensitive.nix;

      homeManagerCfg = userPackages: extraImports: {
        home-manager = {
          useGlobalPkgs = false; # makes hm use nixos's pkgs value
          useUserPackages = userPackages;
          extraSpecialArgs = { inherit inputs; }; # allows access to flake inputs in hm modules
          users.jakob =
            { config, pkgs, ... }:
            {
              nixpkgs.overlays =
                [
                ];
              #home.homeDirectory = nixpkgs-darwin.lib.mkForce "/Users/jakob";
              shell = pkgs.zsh;

              imports = [
                inputs.nix-index-database.homeModules.nix-index
                inputs.agenix.homeManagerModules.default
                inputs.nixpkgs-darwin
                ./users/jakob/dots.nix
                manualSensitiveDarwin
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
          {
            nixpkgs.overlays =
              [
              ];
          }

          # Base
          inputs.agenix.darwinModules.default
          nix-homebrew.darwinModules.nix-homebrew

          # Imports
          ./machines/darwin
          ./machines/darwin/MainDev

          # Services
          # ./modules/tailscale
          # ./modules/zerotier

          # Users
          { system.primaryUser = "jakob"; }
          inputs.home-manager-darwin.darwinModules.home-manager
          (inputs.nixpkgs-darwin.lib.attrsets.recursiveUpdate (homeManagerCfg true [ ]) {
            home-manager.users.jakob.home.homeDirectory = inputs.nixpkgs-darwin.lib.mkForce "/Users/jakob";
            home-manager.users.jakob.home.stateVersion = "25.05";
            home-manager.users.jakob.imports = [
              agenix.homeManagerModules.default
              nix-index-database.homeModules.nix-index
              ./users/jakob/dots.nix
              manualSensitiveDarwinMainDev
            ];
          })
        ];
      };

      deploy.nodes = {
        MainServer = {
          hostname = machinesSensitiveVars.MainServer.ipAddress;
          profiles.system = {
            sshUser = machinesSensitiveVars.MainServer.username;
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
          };
          modules = [
            ./homelab

            ./machines/nixos/_common
            ./machines/nixos/MainServer

            ./modules/zfs-root
            ./modules/tailscale
            ./modules/zerotier
            ./modules/deadman-ping
            ./modules/tg-notify
            ./modules/mover

            secrets/default.nix
            agenix.nixosModules.default

            ./users/jakob
            ./users/christine
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = false;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.jakob.imports = [
                agenix.homeManagerModules.default
                nix-index-database.homeModules.nix-index
                ./users/jakob/dots.nix
              ];
              home-manager.backupFileExtension = "bak";
            }
          ];
        };
      };

      # Update dependencies and switch
      # This is a shell script that updates the flake.lock file, commits it, pushes it to the remote repository, and then switches to the new configuration.
      # run with `nix run .#updateDependenciesAndSwitch`
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (system: {
        updateDependenciesAndSwitch =
          let
            pkgs = import nixpkgs { inherit system; };
          in
          let
            app = pkgs.writeShellApplication {
              name = "update-dependencies-and-switch";
              text = ''
                set -e

                echo "[1/4] Updating flake.lock..."
                nix --experimental-features 'nix-command flakes' flake update

                echo "[2/4] Committing lockfile..."
                git add flake.lock
                git commit -m "chore: update flake.lock with new dependency revisions" || true

                echo "[3/4] Pushing to remote..."
                git push

                if [[ "$(uname)" == "Darwin" ]]; then
                  echo "[4/4] Switching to new config with nix-darwin..."
                  sudo darwin-rebuild switch --flake .#
                else
                  echo "[4/4] Not running nix-darwin switch on non-macOS system."
                fi
              '';
            };
          in
          {
            type = "app";
            program = "${app}/bin/update-dependencies-and-switch";
          };

        pullAndSwitch =
          let
            pkgs = import nixpkgs { inherit system; };
          in
          let
            app = pkgs.writeShellApplication {
              name = "pull-and-switch";
              text = ''
                set -e

                echo "[1/2] Pulling latest config from Git..."
                if [[ "$(uname)" != "Darwin" ]]; then
                  cd /etc/nixos
                fi
                git pull

                if [[ "$(uname)" == "Darwin" ]]; then
                  echo "[2/2] Rebuilding and switching macOS system..."
                  sudo nix run nix-darwin -- switch --flake .#
                else
                  echo "[2/2] Rebuilding and switching Linux system..."
                  nixos-rebuild switch --flake .#
                fi
              '';
            };
          in
          {
            type = "app";
            program = "${app}/bin/pull-and-switch";
          };
      });
    };
}
