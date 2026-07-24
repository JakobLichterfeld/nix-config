{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs) fetchFromGitHub buildGoModule;
  service = "fritzbox-exporter"; # as we do not write fritzbox_exporter in service names
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. USERNAME, PASSWORD, GATEWAY_URL and GATEWAY_LUAURL";
      type = with lib.types; nullOr path;
      default = config.age.secrets.fritzboxExporterEnv.path;
      example = lib.literalExpression ''
        pkgs.writeText "fritzbox-exporter-secret-environment" '''
          USERNAME='your FritzBox username goes here'
          PASSWORD='your FritzBox password goes here'
          GATEWAY_URL='http://<your FritzBox IP>:49000'
          GATEWAY_LUAURL='http://<your FritzBox IP>'
        '''
      '';
    };
    fiberMetrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Collect fiber SFP metrics (gateway_fiber_*) via the Lua interface. Enable once the FRITZ!Box uplink is fiber; on DSL the fiber Lua page returns no SFP data and every scrape logs collect errors.";
    };
    metricsFile = lib.mkOption {
      description = "JSON file with the UPnP/TR-064 metric definitions, adapted to the FRITZ!Box model in use";
      type = lib.types.path;
      default = ./metrics.json;
    };
    luaMetricsFile = lib.mkOption {
      description = "JSON file with the Lua metric definitions, adapted to the FRITZ!Box model in use";
      type = lib.types.path;
      default = ./metrics-lua.json;
    };
    prometheus = {
      listenPort = lib.mkOption {
        type = lib.types.int;
        description = "Port where the Prometheus metrics for Fritz!Box are exposed";
        default = 9042;
      };
      scrapeConfig = lib.mkOption {
        type = lib.types.attrs;
        default = {
          job_name = "${service}";
          metrics_path = "/metrics"; # Flower exposes metrics here
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.prometheus.listenPort}" ];
            }
          ];
          scrape_timeout = "20s";
        };
        description = "Prometheus scrape configuration for fritzbox_exporter.";
      };
    };
  };
  config =
    let
      fritzbox_exporter = buildGoModule rec {
        pname = "fritzbox_exporter";
        version = "latest";

        nativeBuildInputs = with pkgs; [ pkg-config ];

        src = fetchFromGitHub {
          owner = "sberk42";
          repo = "fritzbox_exporter";
          rev = "5547846785cf0c2d311ac65ff698f031520ecbab";
          /*
            On Dev machine from the repository root, determine this hash without
            building MainServer. The command reads `rev` from this file:

              export FRITZBOX_EXPORTER_REV="$(sed -n 's/^[[:space:]]*rev = "\([^"]*\)";/\1/p' homelab/services/prometheus/fritzbox-exporter/default.nix)"
              nix run nixpkgs#nix-prefetch-github -- sberk42 fritzbox_exporter --rev "$FRITZBOX_EXPORTER_REV"

            Copy the reported hash to `sha256` and commit it.
          */
          sha256 = "sha256-If0qNpm9Wpl2/WBNC4p4tGUfYFRomr9jpwxM5Cg0oK0=";
        };

        /*
          After fixing `sha256`, run this separately on Dev machine from the
          repository root. It reads the same `rev` from this file and builds
          only the Go module dependency derivation:

            export FRITZBOX_EXPORTER_REV="$(sed -n 's/^[[:space:]]*rev = "\([^"]*\)";/\1/p' homelab/services/prometheus/fritzbox-exporter/default.nix)"
            nix build --no-link --impure --expr '
              let
                flake = builtins.getFlake (toString ./.);
                pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
              in pkgs.buildGoModule {
                pname = "fritzbox_exporter";
                version = "latest";
                src = builtins.fetchGit {
                  url = "https://github.com/sberk42/fritzbox_exporter.git";
                  rev = builtins.getEnv "FRITZBOX_EXPORTER_REV";
                };
                vendorHash = pkgs.lib.fakeHash;
              }'

          Copy the reported `got:` hash to `vendorHash` and commit it.
        */
        vendorHash = "sha256-+B7GfSWV6F1b88l4hfeEJM73CUG2niQSud5F3NGi394=";

        meta = with lib; {
          description = "Fritz!Box Upnp statistics exporter for prometheus";
          homepage = "https://github.com/sberk42/fritzbox_exporter";
          license = licenses.asl20;
          maintainers = with maintainers; [ JakobLichterfeld ];
        };

        postInstall = ''
          install -Dm644 metrics.json $out/metrics.json
          install -Dm644 metrics-lua.json $out/metrics-lua.json
        '';
      };
      luaMetricsFile =
        if cfg.fiberMetrics then
          cfg.luaMetricsFile
        else
          pkgs.runCommand "metrics-lua-nofiber.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
            jq '.metrics |= map(select(.promDesc.fqName | startswith("gateway_fiber_") | not))' \
              ${cfg.luaMetricsFile} > $out
          '';
    in
    lib.mkIf cfg.enable {

      users.groups."${service}" = { };
      users.users."${service}" = {
        isSystemUser = true;
        createHome = lib.mkForce false;
        description = "Runs ${service} service";
        group = "${service}";
      };

      systemd.services."${service}" = {
        description = "FRITZ!Box Prometheus metrics exporter";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          LISTEN_ADDRESS = "127.0.0.1:${toString cfg.prometheus.listenPort}";
        };
        serviceConfig = {
          User = "${service}";
          Group = "${service}";
          WorkingDirectory = "${fritzbox_exporter}";
          # ReadWritePaths = [
          #   cfg.stateDir
          #   cfg.mediaDir
          #   cfg.consumptionDir
          # ];
          Restart = "on-failure";
          RestartSec = 5;
          EnvironmentFile = lib.mkIf (cfg.secretEnvironmentFile != null) cfg.secretEnvironmentFile;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateMounts = true;
          PrivateNetwork = false; # as we need to connect to the /metrics endpoint
          PrivateTmp = true;
          PrivateUsers = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ]; # IPv4 + IPv6 only
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "@setuid"
            "@keyring"
          ];
          UMask = "0066";

          ExecStart = ''
            ${fritzbox_exporter}/bin/fritzbox_exporter \
              -metrics-file ${cfg.metricsFile} \
              -lua-metrics-file ${luaMetricsFile}
          '';
          StandardOutput = "journal";
          StandardError = "journal";

        };
      };

    };
}
