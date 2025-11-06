{
  description = "Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05?shallow=1";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=1";
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin?shallow=1";
    nixpkgs-darwin-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable?shallow=1";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-darwin-unstable = {
      url = "github:LnL7/nix-darwin/master?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-darwin-unstable";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew?shallow=1";

    # Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core?shallow=1";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask?shallow=1";
      flake = false;
    };
    # automatically update Homebrew, installed via declarative tap management of nix-homebrew
    homebrew-domt4-autoupdate = {
      url = "github:DomT4/homebrew-autoupdate?shallow=1";
      flake = false;
    };
    # Spotube
    homebrew-spotube = {
      url = "github:KRTirtho/homebrew-apps?shallow=1";
      flake = false;
    };
    # sshfs-mac
    homebrew-fuse = {
      url = "github:gromgit/homebrew-fuse?shallow=1";
      flake = false;
    };
    # TabbyML
    homebrew-tabbyml = {
      url = "github:TabbyML/homebrew-tabby?shallow=1";
      flake = false;
    };

    home-manager = {
      # url = "github:nix-community/home-manager/release-25.05?shallow=1"; # gets timeouts
      url = "https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-darwin = {
      # url = "github:nix-community/home-manager/release-25.05?shallow=1"; # gets timeouts
      url = "https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    home-manager-darwin-unstable = {
      url = "github:nix-community/home-manager/master?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-darwin-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs?shallow=1";

    teslamate = {
      url = "github:teslamate-org/teslamate?rev=904bf708358002130f4ea8ffa97d7e2c035b370d"; # v2.2.0
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spotblock = {
      url = "github:vincentkenny01/spotblock?shallow=1";
      flake = false;
    };

    # Linkwarden, as PR is not yet merged
    # TODO(JakobLichterfeld): remove once the PR is merged: https://github.com/NixOS/nixpkgs/pull/347353
    linkwarden-pr = {
      url = "github:NixOS/nixpkgs/096e196f0ebfca516b8c271a710a33928abc60fb?shallow=1";
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
    in
    {
      darwinConfigurations."MainDev" = inputs.nix-darwin-unstable.lib.darwinSystem {
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
          manualSensitiveDarwin
          manualSensitiveDarwinMainDev

          # Services
          # ./modules/tailscale
          # ./modules/zerotier

          # Users
          { system.primaryUser = "jakob"; }
          inputs.home-manager-darwin-unstable.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = false; # makes hm use nixos's pkgs value
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; }; # allows access to flake inputs in hm modules
              backupFileExtension = "bak";
              users.jakob = {
                imports = [ ./users/jakob/home.nix ];
                home.homeDirectory = inputs.nixpkgs-darwin-unstable.lib.mkForce "/Users/jakob";
              };
            };
          }
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

      nixosConfigurations =
        let
          system = "x86_64-linux";
        in
        {
          MainServer = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
              inherit self;
              inherit machinesSensitiveVars;
              pkgsUnstable = import inputs.nixpkgs-unstable {
                inherit system;
              };
            };
            modules = [
              ./homelab
              # Linkwarden, as PR is not yet merged
              # TODO(JakobLichterfeld): remove once the PR is merged: https://github.com/NixOS/nixpkgs/pull/347353
              "${inputs.linkwarden-pr}/nixos/modules/services/web-apps/linkwarden.nix"
              (
                { config, pkgs, ... }:
                {
                  nixpkgs.overlays = [
                    # Overlay for patched prisma from the PR
                    (final: prev: {
                      prisma = import "${inputs.linkwarden-pr}/pkgs/by-name/pr/prisma/package.nix" {
                        inherit (prev)
                          lib
                          fetchFromGitHub
                          stdenv
                          nodejs
                          pnpm_9
                          prisma-engines
                          jq
                          makeWrapper
                          moreutils
                          callPackage
                          ;
                      };
                    })
                    # Overlay for linkwarden with localFontPatch
                    (final: prev: {
                      linkwarden = import "${inputs.linkwarden-pr}/pkgs/by-name/li/linkwarden/package.nix" {
                        inherit (prev)
                          lib
                          stdenvNoCC
                          buildNpmPackage
                          fetchFromGitHub
                          fetchYarnDeps
                          makeBinaryWrapper
                          nixosTests
                          yarnConfigHook
                          fetchpatch

                          bash
                          monolith
                          nodejs
                          openssl
                          google-fonts
                          playwright-driver
                          prisma
                          prisma-engines
                          ;
                      };
                    })
                  ];
                }
              )

              ./machines/nixos/_common
              ./machines/nixos/MainServer

              ./modules/zfs-root
              ./modules/tailscale
              ./modules/zerotier
              ./modules/email
              ./modules/deadman-ping
              ./modules/tg-notify
              ./modules/nvme-thermal-management
              ./modules/mover

              secrets/default.nix
              agenix.nixosModules.default

              ./users/jakob
              ./users/christine
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = false; # makes hm use nixos's pkgs value
                  extraSpecialArgs = { inherit inputs; }; # allows access to flake inputs in hm modules
                  backupFileExtension = "bak";
                  users.jakob.imports = [ ./users/jakob/home.nix ];
                };
              }
            ];
          };
        };

      # Applications for managing this Nix configuration.
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          sudo-keep-alive-wrapper = pkgs.writeShellApplication {
            name = "sudo-keep-alive-wrapper";
            runtimeInputs = [ pkgs.bash ];
            text = ''
              #!/usr/bin/env bash
              set -e
              if [ "$#" -eq 0 ]; then
                echo "Usage: $0 <command-to-run-with-sudo>" >&2
                exit 1
              fi
              echo "Keeping sudo session alive for the duration of the command..."
              sudo -v
              while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
              SUDO_KEEPALIVE_PID=$!
              trap 'kill "$SUDO_KEEPALIVE_PID"' EXIT
              sudo "$@"
              trap - EXIT
              kill "$SUDO_KEEPALIVE_PID"
            '';
          };
        in
        {
          # Update dependencies and switch
          # Update dependencies in flake.lock, commits it, pushes it to the remote repository, and then switches to the new configuration.
          #  run with: `nix run .#updateDependenciesAndSwitch`
          updateDependenciesAndSwitch =
            let
              app = pkgs.writeShellApplication {
                name = "update-dependencies-and-switch";
                text = ''
                  export SUDO_WRAPPER="${sudo-keep-alive-wrapper}/bin/sudo-keep-alive-wrapper"
                  ${builtins.readFile ./apps/update-dependencies-and-switch.sh}
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/update-dependencies-and-switch";
            };

          # Pull and switch
          # Pull the latest configuration from git (with rebase) and switch to it.
          # Run with: `nix run .#pullAndSwitch`
          pullAndSwitch =
            let
              app = pkgs.writeShellApplication {
                name = "pull-and-switch";
                text = ''
                  export SUDO_WRAPPER="${sudo-keep-alive-wrapper}/bin/sudo-keep-alive-wrapper"
                  ${builtins.readFile ./apps/pull-and-switch.sh}
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/pull-and-switch";
            };
        }
      );
    };
}
