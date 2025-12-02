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
          rev = "b61ea2bc17626994ed319a5640d408c0cc9c0061";
          sha256 = "sha256-vXpWcEgi3YFeANMO1aezcHvYo0fvEkdwEJ1TJEeo+3c=";
        };

        vendorHash = "sha256-kI1P0sDp+tKtQe6apqbQzgRj/6pJ4ncEuQlZ8Cmix1w=";

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
              -metrics-file ${fritzbox_exporter}/metrics.json \
              -lua-metrics-file ${fritzbox_exporter}/metrics-lua.json
          '';
          StandardOutput = "journal";
          StandardError = "journal";

        };
      };

    };
}
