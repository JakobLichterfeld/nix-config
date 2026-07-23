{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  service = "teslamate";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  cfgGrafana = config.homelab.services.teslamate-grafana;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 4000;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "TeslaMate";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "A powerful, self-hosted data logger for your Tesla.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "teslamate.png";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Tesla";
    };
    postgres.host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    postgres.user = lib.mkOption {
      type = lib.types.str;
      default = "teslamate";
    };
    postgres.database = lib.mkOption {
      type = lib.types.str;
      default = "teslamate";
    };
    postgres.listenPort = lib.mkOption {
      type = lib.types.int;
      default = 5432;
    };
    mqtt.listenPort = lib.mkOption {
      type = lib.types.int;
      default = 1883;
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
          (blackbox.mkHttpTarget "${
            service
          }" "http://127.0.0.1:${toString cfg.listenPort}/health_check" "internal") # health check endpoint
          (blackbox.mkHttpTarget "${service}" "${cfg.url}/health_check" "external") # health check endpoint
        ];
    };
  };

  options.homelab.services.teslamate-grafana = {
    # used for automatic generation of the service entry in the homepage
    enable = lib.mkEnableOption {
      description = "Enable teslamate-grafana";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "teslamate-grafana.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 3000;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "TeslaMate Grafana";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Visualization of TeslaMate data.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "grafana";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Tesla";
    };

    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "teslamate-grafana" "http://127.0.0.1:${toString cfgGrafana.listenPort}"
            "internal"
          )
          (blackbox.mkHttpTarget "teslamate-grafana" "${cfgGrafana.url}" "external")
        ];
    };
  };

  imports = [ inputs.teslamate.nixosModules.default ];

  config = lib.mkIf cfg.enable {

    services.teslamate = {
      enable = true;
      secretsFile = config.age.secrets.teslamateEnv.path;
      autoStart = true;
      # listenAddress = "127.0.0.1"; # blank for all addresses
      port = cfg.listenPort;
      virtualHost = "${cfg.url}";
      urlPath = "/";

      postgres = {
        enable_server = true;
        user = cfg.postgres.user;
        database = cfg.postgres.database;
        host = "127.0.0.1";
        port = cfg.postgres.listenPort;
      };

      grafana = {
        enable = true;
        listenAddress = "0.0.0.0"; # listen on all addresses
        port = cfgGrafana.listenPort;
        urlPath = "/";
        secretKeyFile = config.age.secrets.grafanaSecretKeyFile.path;
      };

      mqtt = {
        enable = true;
        host = "127.0.0.1";
        port = cfg.mqtt.listenPort;
      };
    };

    # Prometheus exporter for PostgreSQL
    services.prometheus.exporters.postgres.environmentFile = config.age.secrets.teslamateEnv.path;
    # the Environment file must contain the following with real values:
    # DATA_SOURCE_NAME=postgres://${cfg.postgres.user}:${DATABASE_PASS}@${cfg.postgres.host}:${cfg.postgres.listenPort}/${cfg.postgres.database}?sslmode=disable
    services.prometheus.exporters.postgres.dataSourceName = "$DATA_SOURCE_NAME"; # as the eventsub is not implemented for this exporter, we must use the complete data source name

    homelab.services.teslamate-grafana = {
      enable = true;
    };

    # Mosquitto MQTT broker
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          # TODO: use authentication
          acl = [ "pattern readwrite #" ];
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.mqtt.listenPort ];

    # TeslaMate
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };

    # Grafana
    services.caddy.virtualHosts."${cfgGrafana.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfgGrafana.listenPort}
      '';
    };
  };
}
