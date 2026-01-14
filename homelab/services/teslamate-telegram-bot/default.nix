{
  config,
  lib,
  inputs,
  ...
}:
let
  service = "teslamate-telegram-bot";
  cfg = config.homelab.services.teslamate-telegram-bot;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the secrets for the teslamate telegram bot";
      default = config.age.secrets.teslamateEnvTelegramBot.path;
    };
  };

  imports = [ inputs.teslamate-telegram-bot.nixosModules.default ];

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

    services.teslamate-telegram-bot = {
      enable = true;
      secretsFile = cfg.secretsFile;
      # carId=1; # optional, defaults to 1
      mqtt = {
        host = config.services.teslamate.mqtt.host;
        port = config.services.teslamate.mqtt.port;
        # user = "";
        # namespace = ""; # optional, only needed when you specified MQTT_NAMESPACE on your TeslaMate installation
      };
      autoStart = true;
    };
  };
}
