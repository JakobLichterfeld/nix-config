{
  config,
  lib,
  ...
}:
let
  service = "prometheus";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 9090;
    };
    listenPortAlertmanager = lib.mkOption {
      type = lib.types.int;
      default = 9093;
    };
    listenPortNodeExporter = lib.mkOption {
      type = lib.types.int;
      default = 9100;
    };
    telegramCredentialsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file with the Telegram Bot token";
      example = lib.literalExpression ''
        pkgs.writeText "telegram-credentials" '''
          BOT_TOKEN=secret
        '''
      '';
    };
    telegramChatId = lib.mkOption {
      type = lib.types.int;
      description = "Telegram Bot chat ID to send alerts to";
      example = lib.literalExpression ''
        "-123456789"
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Prometheus";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Monitoring and alerting system";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "prometheus.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      port = cfg.listenPort;
      webExternalUrl = "https://${cfg.url}:${toString cfg.listenPort}";
      scrapeConfigs =
        # each homelab service that has `scrapeConfig` defined will be added to the Prometheus scrape configuration
        # in the homelab.services it should look like this for example:
        #     prometheus.scrapeConfig = lib.mkOption {
        #   type = lib.types.attrs;
        #   default = {
        #     job_name = "${service}";
        #     static_configs = [
        #       {
        #         targets = [ "localhost:${toString listenPort}" ];
        #       }
        #     ];
        #   };
        # };
        (lib.pipe config.homelab.services [
          (lib.filterAttrs (_: s: s.enable or false))
          (lib.mapAttrsToList (
            _: s: if s ? prometheus && s.prometheus ? scrapeConfig then s.prometheus.scrapeConfig else null
          ))
          (lib.filter (cfg: cfg != null))
        ])
        ++ [
          {
            job_name = "prometheus";
            static_configs = [
              { targets = [ "localhost:${toString cfg.listenPort}" ]; }
            ];
          }
          {
            job_name = "node";
            static_configs = [
              { targets = [ "localhost:${toString cfg.listenPortNodeExporter}" ]; }
            ];
          }
        ];

      # Alertmanager
      alertmanager = {
        enable = true;
        port = cfg.listenPortAlertmanager;
        environmentFile = cfg.telegramCredentialsFile; # includes bot_token and chat_id
        configuration = {
          route = {
            receiver = "telegram";
          };
          receivers = [
            {
              name = "telegram";
              telegram_configs = [
                {
                  # see https://prometheus.io/docs/alerting/latest/configuration/#telegram_config
                  bot_token = "\${BOT_TOKEN}"; # set in the environment file
                  chat_id = cfg.telegramChatId; # setting in evironment file is not supported as it must be a int64 and env is a string
                  send_resolved = true; # whether to send resolved alerts
                  parse_mode = "HTML"; # Parse mode for telegram message, supported values are MarkdownV2, Markdown, HTML and empty string for plain text
                  #   message = ''
                  #     <b>{{ .Status | toUpper }}</b> 🔔
                  #     {{ range .Alerts }}
                  #     <b>{{ .Labels.alertname }}</b>: {{ .Annotations.summary }}
                  #     <i>{{ .Annotations.description }}</i>
                  #     {{ end }}
                  #   '';
                }
              ];
            }
          ];
        };
      };

      exporters = {
        #Node Exporter
        node = {
          enable = true;
          openFirewall = true;
          port = cfg.listenPortNodeExporter;
          enabledCollectors = [
            "cpu" # Collect CPU statistics
            "diskstats" # Collect disk statistics
            "filesystem" # Collect filesystem statistics
            "loadavg" # Collect load average statistics
            "meminfo" # Collect memory statistics
            "netdev" # Collect network device statistics
            "time" # Collect system time statistics
            "systemd" # Collect systemd statistics
          ];
          extraFlags = [
            "--collector.ethtool" # Collect ethtool statistics
            "--collector.softirqs" # Collect softirq statistics
            "--collector.tcpstat" # Collect TCP statistics
          ];
        };

        mqtt.enable = config.services.mosquitto.enable;

        postgres.enable = config.services.postgresql.enable;

        zfs.enable = true;
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };
}
