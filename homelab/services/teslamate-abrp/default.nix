{
  config,
  lib,
  inputs,
  ...
}:
let
  service = "teslamate-abrp";
  cfg = config.homelab.services.teslamate-abrp;
  homelab = config.homelab;
  teslamate-abrp-version = "3.3.0";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homelab.services.teslamate.enable;
        message = "${service} cannot be enabled when teslamate is not enabled.";
      }
      {
        assertion = config.services.mosquitto.enable;
        message = "${service} cannot be enabled when mosquitto is not enabled.";
      }
    ];

    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          teslamate-abrp = {
            image = "fetzu/teslamate-abrp:${teslamate-abrp-version}";
            autoStart = true;
            environmentFiles = [ config.age.secrets.teslamateEnvABRP.path ];
            environment = {
              MQTT_SERVER = "host.containers.internal";
              MQTT_PORT = "${toString config.homelab.services.teslamate.listenPortMqtt}";
            };
            extraOptions = lib.optional (
              !config.virtualisation.podman.defaultNetwork.settings.dns_enabled
            ) "--add-host=host.containers.internal:10.88.0.1";
          };
        };
      };
    };
    systemd.services."podman-${service}" = {
      after = [
        "network-online.target"
        "mosquitto.service"
        "teslamate.service"
      ];
      requires = [
        "mosquitto.service"
        "teslamate.service"
      ];
      wants = [ "network-online.target" ];
    };
  };
}
