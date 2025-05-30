{
  config,
  pkgs,
  lib,
  ...
}:
let
  service = "prometheus";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  serviceSubService = "alertmanager";
  cfgSubService = config.homelab.services.${serviceSubService};
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

  options.homelab.services.${serviceSubService} = {
    # used for automatic generation of the service entry in the homepage
    enable = lib.mkEnableOption {
      description = "Enable ${serviceSubService}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${serviceSubService}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = cfg.listenPortAlertmanager;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "${serviceSubService}";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Managing alerts sent by Prometheus server.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "alertmanager.svg";
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
        webExternalUrl = "https://${cfgSubService.url}";
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
                  chat_id = cfg.telegramChatId; # setting in environment file is not supported as it must be a int64 and env is a string
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

      alertmanagers = [
        {
          static_configs = [
            { targets = [ "${cfgSubService.url}" ]; }
          ];
        }
      ];

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

      ruleFiles =
        let
          customRulesInGroups = [
            {
              groupName = "system";
              rules = [
                {
                  alert = "SystemdUnitFailed";
                  expr = ''systemd_unit_state{state="failed"} > 0'';
                  for = "1m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "Systemd unit failed";
                    description = "Unit {{ $labels.name }} is in failed state on {{ $labels.instance }}.";
                  };
                }
                {
                  alert = "NodeCPUUsageHigh";
                  expr = ''100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 90'';
                  for = "2m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "High CPU usage";
                    description = "Instance {{ $labels.instance }} CPU usage is over 90% for more than 2 minutes.";
                  };
                }
                {
                  alert = "NodeMemoryUsageHigh";
                  expr = ''(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9'';
                  for = "2m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "High memory usage";
                    description = "Instance {{ $labels.instance }} is using more than 90% of memory.";
                  };
                }
                {
                  alert = "ClockNotSynchronizing";
                  expr = ''min_over_time(node_timex_sync_status[1m]) == 0 and node_timex_maxerror_seconds >= 16'';
                  for = "5m";
                  labels = {
                    severity = "critical";
                  };
                  annotations = {
                    summary = "Clock not synchronizing";
                    description = "Instance {{ $labels.instance }} clock is not synchronizing.";
                  };
                }
              ];
            }
            {
              groupName = "filesystem";
              rules = [
                {
                  alert = "NodeFilesystemAlmostFull";
                  expr = ''(node_filesystem_avail_bytes{fstype=~"ext4|xfs|zfs"} / node_filesystem_size_bytes{fstype=~"ext4|xfs|zfs"}) < 0.10'';
                  for = "5m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "Filesystem almost full";
                    description = "Filesystem on {{ $labels.instance }} at {{ $labels.mountpoint }} is almost full.";
                  };
                }
                {
                  alert = "NodeDiskIOWaitHigh";
                  expr = ''rate(node_disk_io_time_seconds_total[5m]) > 0.1'';
                  for = "2m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "High disk I/O wait time";
                    description = "Instance {{ $labels.instance }} has high disk I/O wait time.";
                  };
                }

              ];
            }

            {
              groupName = "network";
              rules = [
                {
                  alert = "NodeNetworkReceiveErrors";
                  expr = ''rate(node_network_receive_errors_total[5m]) > 0'';
                  for = "2m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "Network receive errors";
                    description = "Instance {{ $labels.instance }} has network receive errors.";
                  };
                }
                {
                  alert = "NodeNetworkTransmitErrors";
                  expr = ''rate(node_network_transmit_errors_total[5m]) > 0'';
                  for = "2m";
                  labels = {
                    severity = "warning";
                  };
                  annotations = {
                    summary = "Network transmit errors";
                    description = "Instance {{ $labels.instance }} has network transmit errors.";
                  };
                }
              ];
            }
          ];
        in
        builtins.attrValues (
          lib.listToAttrs (
            lib.map (group: {
              name = "${group.groupName}.rules.yml";
              value = pkgs.writeText "${group.groupName}.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = group.groupName;
                      rules = lib.map (rule: {
                        alert = rule.alert;
                        expr = rule.expr;
                        for = rule.for;
                        labels = rule.labels;
                        annotations = rule.annotations;
                      }) group.rules;
                    }
                  ];
                }
              );
            }) customRulesInGroups
          )
        );

    };

    # Prometheus
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };

    # Alertmanager
    services.caddy.virtualHosts."${cfgSubService.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfgSubService.listenPort}
      '';
    };
  };
}
