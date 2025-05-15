{
  config,
  lib,
  vars,
  inputs,
  machinesSensitiveVars,
  ...
}:
let
  service = "teslamate";
  cfg = config.homelab.services.teslamate;
  homelab = config.homelab;
  teslamate-abrp-version = "3.3.0";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${vars.serviceConfigRoot}/${service}";
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
      default = "${service}";
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
    listenPortPostgres = lib.mkOption {
      type = lib.types.int;
      default = 5432;
    };
    urlGrafana = lib.mkOption {
      type = lib.types.str;
      default = "${service}_grafana.${homelab.baseDomain}";
    };
    listenPortGrafana = lib.mkOption {
      type = lib.types.int;
      default = 3000;
    };
    listenPortMqtt = lib.mkOption {
      type = lib.types.int;
      default = 1883;
    };
  };

  imports = [ inputs.teslamate.nixosModules.default ];

  config = lib.mkIf cfg.enable {

    services.teslamate = {
      enable = true;
      secretsFile = config.age.secrets.teslamateEnv.path;
      autoStart = true;
      listenAddress = "127.0.0.1";
      port = cfg.listenPort;
      virtualHost = "${cfg.url}";
      urlPath = "/";

      postgres = {
        enable_server = true;
        user = "teslamate";
        database = "teslamate";
        host = "127.0.0.1";
        port = cfg.listenPortPostgres;
      };

      grafana = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = cfg.listenPortGrafana;
        urlPath = "/";
      };

      mqtt = {
        enable = true;
        host = "${config.homelab.baseDomain}";
        port = cfg.listenPortMqtt;
      };
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

    networking.firewall.allowedTCPPorts = [ cfg.listenPortMqtt ];

    #ABRP integration
    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          teslamate-abrp = {
            image = "fetzu/teslamate-abrp:${teslamate-abrp-version}";
            autoStart = true;
            environmentFiles = [ config.age.secrets.teslamateEnvABRP.path ];
            environment = {
              MQTT_SERVER = "127.0.0.1:${toString cfg.listenPortMqtt}";
            };
            log-driver = "journald";
            dependsOn = [ "mosquitto.service" ];
          };
        };
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };

    services.caddy.virtualHosts."${cfg.urlGrafana}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPortGrafana}
      '';
    };
  };
}
