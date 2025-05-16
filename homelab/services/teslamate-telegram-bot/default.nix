{
  config,
  lib,
  inputs,
  ...
}:
let
  service = "teslamate-telegram-bot";
  cfg = config.homelab.services.teslamate-telegram-bot;
  homelab = config.homelab;
  teslamate-telegram-bot-version = "0.7.8";
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
          "${service}" = {
            image = "JakobLichterfeld/TeslaMate-Telegram-Bot:${teslamate-telegram-bot-version}";
            autoStart = true;
            environmentFiles = [ config.age.secrets.teslamateEnvTelegramBot.path ];
            environment = {
              # CAR_ID=1; # optional, defaults to 1
              # MQTT_BROKER_HOST=127.0.0.1; # defaults to 127.0.0.1
              MQTT_BROKER_PORT = toString config.homelab.services.teslamate.listenPortMqtt;
              # MQTT_NAMESPACE=namespace; # optional, only needed when you specified MQTT_NAMESPACE on your TeslaMate installation
            };
            log-driver = "journald";
            dependsOn = [
              "mosquitto.service"
              "teslamate.service"
            ];
          };
        };
      };
    };
  };
}
