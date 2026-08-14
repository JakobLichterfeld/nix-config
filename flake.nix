{
  description = "Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05?shallow=1";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=1";
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin?shallow=1";
    nixpkgs-darwin-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable?shallow=1";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05?shallow=1";
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
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05?shallow=1";
      # url = "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz"; # if the above gets timeouts
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-26.05?shallow=1";
      # url = "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz"; # if the above gets timeouts
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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    teslamate = {
      url = "github:teslamate-org/teslamate?rev=d6c43bc8c48784da8f0b701945b80b20911b3d1a"; # v4.1.1
      inputs.nixpkgs.follows = "nixpkgs";
    };

    teslamate-telegram-bot = {
      url = "github:JakobLichterfeld/TeslaMate-Telegram-Bot?rev=c715ad8d562580a943796ebfa611e25cac95a04c"; # v1.1.0
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spotblock = {
      url = "github:vincentkenny01/spotblock?shallow=1";
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
      nixos-wsl,
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
            nixpkgs.overlays = [
              (final: prev: {
                memmon = prev.callPackage ./pkgs/memmon { };
                codegraph = prev.callPackage ./pkgs/codegraph { };
              })
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
          inputs.home-manager-darwin-unstable.darwinModules.home-manager
          ./modules/home-manager.nix
          { home-manager.users.jakob.imports = [ ./users/jakob/home.nix ]; }
        ];
      };

      deploy.nodes = {
        MainServer = {
          hostname = machinesSensitiveVars.MainServer.ipAddress;
          sshUser = machinesSensitiveVars.MainServer.sshUsername; # The user on the remote machine to log in as via SSH.
          profiles.system = {
            user = machinesSensitiveVars.MainServer.adminUsername; # The user on the remote machine to deploy the configuration as.
            sshOpts = [
              "-p"
              (builtins.toString machinesSensitiveVars.MainServer.sshPort)
            ];
            remoteBuild = true;
            interactiveSudo = false;
            autoRollback = true;
            magicRollback = true;
            confirmTimeout = 60;
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

              ./machines/nixos/_common
              ./machines/nixos/MainServer

              ./modules/zfs-root

              ./modules/deadman-ping
              ./modules/dns-updater
              ./modules/email
              ./modules/mover
              ./modules/nvme-thermal-management
              ./modules/tailscale
              ./modules/tg-notify
              ./modules/zerotier

              agenix.nixosModules.default

              ./users
              ./users/jakob
              ./users/christine
              home-manager.nixosModules.home-manager
              ./modules/home-manager.nix
              { home-manager.users.jakob.imports = [ ./users/jakob/home.nix ]; }
            ];
          };

          WslEnvDataIndexer = nixpkgs.lib.nixosSystem {
            # build tarball via the app: `nix run .#buildWslTarballForWslEnvDataIndexer`
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
              nixos-wsl.nixosModules.default

              ./machines/nixos/_common
              ./machines/nixos/WslEnvDataIndexer

              ./modules/data-indexer
              ./modules/deadman-ping

              agenix.nixosModules.default
            ];
          };
        };

      # Applications for managing this Nix configuration.
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                deploy-rs = inputs.deploy-rs.packages.${prev.system}.deploy-rs; # overlay to get deploy-rs package from binary cache instead of building from source
              })
            ];
          };
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
              sudo sh -c 'echo "Defaults timestamp_timeout=-1" > /etc/sudoers.d/sudo-keepalive-temp'
              trap 'sudo rm -f /etc/sudoers.d/sudo-keepalive-temp' EXIT
              sudo "$@"
              trap - EXIT
              sudo rm -f /etc/sudoers.d/sudo-keepalive-temp
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
              meta.description = "Update dependencies in flake.lock, commits it, pushes it to the remote repository, and then switches to the new configuration.";
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
              meta.description = "Pull the latest configuration from git (with rebase) and switch to it.";
            };

          # Deploy MainServer
          # Deploys the MainServer configuration remotely using deploy-rs.
          # Run with: `nix run .#deployMainServer`
          deployMainServer =
            let
              app = pkgs.writeShellApplication {
                name = "deploy-main-server";
                runtimeInputs = [ pkgs.deploy-rs ];
                text = ''
                  deploy "${self}#MainServer" "$@"
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/deploy-main-server";
              meta.description = "Deploy the MainServer configuration remotely using deploy-rs.";
            };
        }
        # The tarball builder is a x86_64-linux derivation and has to run on that platform,
        # so the app is only exposed there.
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {

          # Build WSL tarball
          # Builds the WSL tarball for NixOS-WSL machine named WslEnvDataIndexer.
          # Run on a x86_64-linux machine with: `nix run .#buildWslTarballForWslEnvDataIndexer`
          buildWslTarballForWslEnvDataIndexer =
            let
              app = pkgs.writeShellApplication {
                name = "build-wsl-tarball-for-WslEnvDataIndexer";
                text = ''
                  # Set a high limit for open files for this script's execution
                  ulimit -n 1048576

                  extra_files=$(mktemp -d)
                  # Ensure temp files are cleaned up on exit
                  trap 'rm -rf "$extra_files"' EXIT

                  mkdir -p "$extra_files/persist/ssh"
                  cp "$HOME/.ssh/id_ed25519_wsl_env_data_indexer" "$extra_files/persist/ssh/id_ed25519_wsl_env_data_indexer"
                  cp "$HOME/.ssh/nix-config_local.key.asc" "$extra_files/persist/ssh/nix-config_local.key.asc"

                  # Evaluate and build as the invoking user, only the tarball builder itself needs root.
                  tarball_builder=$(nix build --no-link --print-out-paths \
                    "${self}#nixosConfigurations.WslEnvDataIndexer.config.system.build.tarballBuilder")

                  sudo "$tarball_builder/bin/nixos-wsl-tarball-builder" \
                    --extra-files "$extra_files" \
                    --chown /persist/ssh 1000:100
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/build-wsl-tarball-for-WslEnvDataIndexer";
              meta.description = "Builds the WSL tarball for NixOS-WSL.";
            };
        }
      );

      # deploy-rs checks
      # Only for x86_64-linux: the deploy-activate check depends on the activation path of the
      # MainServer profile, so generating it for aarch64-darwin as well would force building the
      # whole x86_64-linux closure locally on every deploy, defeating `remoteBuild = true`.
      checks.x86_64-linux = deploy-rs.lib.x86_64-linux.deployChecks self.deploy;
    };
}
