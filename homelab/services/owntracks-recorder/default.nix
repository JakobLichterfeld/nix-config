{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "owntracks-recorder";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/owntracks-recorder";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "127.0.0.1";
      description = "IP address where the http interface is exposed";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8083;
    };
    mqtt = {
      enable = lib.mkEnableOption "Owntracks Recorder MQTT integration";
      default = false;
      description = "Enable MQTT integration for Owntracks Recorder";

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "MQTT host";
      };

      port = lib.mkOption {
        type = with lib.types; nullOr port;
        default = 1883;
        description = "MQTT port.";
      };

      topic = lib.mkOption {
        type = lib.types.str;
        default = "owntracks/#";
        description = "MQTT topic(s) the recorder should subscribe to";
      };
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. OTR_GEOKEY";
      type = with lib.types; nullOr path;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "owntracks-recorder-secret-environment" '''
          OTR_GEOKEY = "your-geokey-here"
        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Owntracks Recorder";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Store and access data published by OwnTracks apps";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "owntracks.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
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
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = lib.optional cfg.mqtt.enable [
      {
        assertion = config.services.mosquitto.enable;
        message = "${service} cannot be enabled with MQTT integration when mosquitto is not enabled.";
      }
    ];

    environment.systemPackages = [ pkgs.owntracks-recorder ];

    users.groups.owntracks = { };
    users.users.owntracks = {
      isSystemUser = true;
      createHome = lib.mkForce false;
      description = "Runs owntracks service";
      group = "owntracks";
    };

    # Create directories for Owntracks-Recoder with the correct permissions and ownership.
    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 owntracks owntracks - -" ];

    systemd.services."owntracks-recorder" = {
      description = "Store and access data published by OwnTracks apps";
      after =
        [
          "network-online.target"
        ]
        ++ lib.optional cfg.mqtt.enable [
          "mosquitto.service"
        ];
      requires = lib.optional cfg.mqtt.enable [
        "mosquitto.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "owntracks";
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${pkgs.owntracks-recorder}/bin/ot-recorder --storage ${cfg.stateDir} ${cfg.mqtt.topic}"; # topic is always needed, even if MQTT is not enabled
        EnvironmentFile = lib.mkIf (cfg.secretEnvironmentFile != null) cfg.secretEnvironmentFile;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ]; # IPv4 + IPv6 only
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.stateDir ];
      };
      environment = lib.mkMerge [
        {
          OTR_STORAGEDIR = cfg.stateDir;
          OTR_HTTPHOST = cfg.listenAddress;
          OTR_HTTPPORT = toString cfg.listenPort;
          OTR_HTTPLOGDIR = cfg.stateDir;
          OTR_PRECISION = "8"; # see https://github.com/owntracks/recorder?tab=readme-ov-file#precision
          OTR_PORT = lib.mkIf (!cfg.mqtt.enable) "0"; # disable MQTT if MQTT is not enabled
        }
        (lib.mkIf cfg.mqtt.enable {
          OTR_HOST = cfg.mqtt.host;
          OTR_PORT = toString cfg.mqtt.port;
          # OTR_USER =;
          # OTR_PASS = ;

        })
      ];
    };

    # TODO: Backup owntracks-recorder data, see https://github.com/owntracks/recorder?tab=readme-ov-file#the-lmdb-database

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
    # Android App and iOS App can be configured to use the Caddy URL as the HTTP interface, use HTTP mode with the url: ${cfg.url}/pub
  };
}
