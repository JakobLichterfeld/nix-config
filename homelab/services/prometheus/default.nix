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
  serviceSubServiceTwo = "prometheus-grafana";
  cfgSubService = config.homelab.services.${serviceSubService};
  cfgSubServiceTwo = config.homelab.services.${serviceSubServiceTwo};

  # Stable UID for the Grafana dashboard folder so the direct dashboards URL never
  # changes across rebuilds. Used as single source of truth for both the folder
  # provisioning (folderUid) and the Caddy redirect below.
  grafanaDashboardFolderUid = "prometheus_folder";

in
{
  # FritzBox Exporter
  imports = [
    ./fritzbox-exporter
  ];
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/prometheus2";
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
    listenPortMQTTExporter = lib.mkOption {
      type = lib.types.int;
      default = 9000;
    };
    listenPortPostgreSQLExporter = lib.mkOption {
      type = lib.types.int;
      default = 9187;
    };
    listenPortZfsExporter = lib.mkOption {
      type = lib.types.int;
      default = 9134;
    };
    listenPortSmartctlExporter = lib.mkOption {
      type = lib.types.int;
      default = 9633;
    };
    listenPortBlackboxExporter = lib.mkOption {
      type = lib.types.int;
      default = 9115;
    };
    fritzboxExporter = {
      enable = lib.mkEnableOption {
        description = "Enable fritzbox_exporter";
        default = false;
      };
      listenPort = lib.mkOption {
        type = lib.types.int;
        default = 9042;
      };
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
    enableTestAlert = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable test alert for Prometheus";
    };
    grafanaSecretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the Grafana secret_key for signing data source settings like secrets and passwords";
      default = config.age.secrets.grafanaSecretKeyFile.path;
    };
    grafanaAdminPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the Grafana admin password, applied on first creation of the admin user (e.g. after a state reset) so it does not need to be set manually";
      default = config.age.secrets.grafanaAdminPassword.path;
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
      default = "System Services";
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "prometheus" "localhost:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTargetCritical "alertmanager" "localhost:${toString cfgSubService.listenPort}" "internal")
          (blackbox.mkHttpTarget "node_exporter" "localhost:${toString cfg.listenPortNodeExporter}"
            "internal"
          )
          (blackbox.mkHttpTarget "zfs_exporter" "localhost:${toString cfg.listenPortZfsExporter}" "internal")
          (blackbox.mkHttpTarget "smartctl_exporter" "localhost:${toString cfg.listenPortSmartctlExporter}"
            "internal"
          )
          (blackbox.mkHttpTargetCritical "blackbox_exporter"
            "localhost:${toString cfg.listenPortBlackboxExporter}"
            "internal"
          )
        ]
        ++ lib.optional config.services.mosquitto.enable (
          blackbox.mkHttpTarget "mqtt_exporter" "127.0.0.1:${toString cfg.listenPortMQTTExporter}" "internal" # as the MQTT exporter does only resolve localhost on ipv6 we enforce ipv4 here
        )
        ++ lib.optional config.services.postgresql.enable (
          blackbox.mkHttpTarget "postgresql_exporter" "localhost:${toString cfg.listenPortPostgreSQLExporter}"
            "internal"
        );
    };
    blackbox.hostSpecificTargets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      description = "List of host specific blackbox probe targets";
      defaultTargets = [ ];
    };
  };

  # Alertmanager
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
      default = "Prometheus Alertmanager";
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
      default = "System Services";
    };
  };

  # Grafana
  options.homelab.services.${serviceSubServiceTwo} = {
    # used for automatic generation of the service entry in the homepage
    enable = lib.mkEnableOption {
      description = "Enable ${serviceSubServiceTwo}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${serviceSubServiceTwo}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 3000;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Prometheus Grafana";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Data visualization for Prometheus Data.";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "grafana.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "System Services";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.${service} =
        let
          # Collect targets from all enabled homelab.services that have `blackboxTargets` defined
          activeServices = lib.filterAttrs (_: s: s.enable or false) config.homelab.services;

          # Flatten the list of blackboxTargets from all active services
          blackboxTargets =
            lib.flatten (
              lib.mapAttrsToList (_: s: if s ? blackbox.targets then s.blackbox.targets else [ ]) activeServices
            )
            # add the host specific blackbox targets if any
            ++ (if cfg.blackbox.hostSpecificTargets != [ ] then cfg.blackbox.hostSpecificTargets else [ ]);
        in
        {
          enable = true;
          port = cfg.listenPort;
          webExternalUrl = "https://${cfg.url}";
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
              {
                job_name = "mqtt";
                static_configs = [
                  { targets = [ "localhost:${toString cfg.listenPortMQTTExporter}" ]; }
                ];
              }
              {
                job_name = "postgresql";
                static_configs = [
                  { targets = [ "localhost:${toString cfg.listenPortPostgreSQLExporter}" ]; }
                ];
              }
              {
                job_name = "zfs";
                static_configs = [
                  {
                    targets = [ "localhost:${toString cfg.listenPortZfsExporter}" ];
                  }
                ];
              }
              {
                job_name = "smartctl";
                static_configs = [
                  { targets = [ "localhost:${toString cfg.listenPortSmartctlExporter}" ]; }
                ];
              }
              {
                job_name = "blackbox";
                metrics_path = "/probe";

                static_configs = map (entry: {
                  targets = [ entry.target ];
                  labels.module = entry.module;
                }) blackboxTargets;

                relabel_configs = [
                  {
                    source_labels = [ "__address__" ];
                    target_label = "__param_target";
                  }
                  {
                    source_labels = [ "__param_target" ];
                    target_label = "instance";
                  }
                  {
                    source_labels = [ "module" ];
                    target_label = "__param_module";
                  }
                  {
                    target_label = "__address__";
                    replacement = "localhost:${toString cfg.listenPortBlackboxExporter}"; # Address of the Blackbox Exporter
                  }
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
                      # Template constraints (earlier attempts silently sent nothing):
                      # - only Alertmanager template functions plus Go text/template builtins exist;
                      #   Sprig/Helm helpers like `default` are undefined and abort rendering
                      #   (visible as "notify retry canceled" in journalctl -u alertmanager)
                      # - label/annotation values must be escaped with `html`, otherwise Telegram
                      #   rejects the message with "can't parse entities" when a value contains < or &
                      # - missing keys in .Labels/.Annotations render as "" (KV map), so `if` guards
                      #   replace `default`
                      # - HTML mode allows only b/i/u/s/code/pre/a tags; newlines format the rest
                      message = ''
                        {{- if eq .Status "firing" }}🔥 <b>FIRING</b>{{ else }}✅ <b>RESOLVED</b>{{ end }} ({{ len .Alerts }})
                        {{ range .Alerts }}
                        {{ if eq .Labels.severity "critical" }}🔴{{ else if eq .Labels.severity "warning" }}🟠{{ else }}🔵{{ end }} <b>{{ .Labels.alertname | html }}</b>
                        {{ if .Annotations.summary }}{{ .Annotations.summary | html }}
                        {{ end }}{{ if .Annotations.description }}📖 {{ .Annotations.description | html }}
                        {{ end }}{{ range .Labels.SortedPairs }}{{ if and (ne .Name "alertname") (ne .Name "severity") (ne .Name "instance") }}🏷 {{ .Name }}: <code>{{ .Value | html }}</code>
                        {{ end }}{{ end }}{{ if .GeneratorURL }}🔗 <a href="{{ .GeneratorURL | html }}">Source</a>
                        {{ end }}{{ end }}
                      '';
                    }
                  ];
                }
              ];
            };
          };

          alertmanagers = [
            {
              static_configs = [
                { targets = [ "localhost:${toString cfgSubService.listenPort}" ]; }
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

            mqtt = {
              enable = config.services.mosquitto.enable;
              listenAddress = "0.0.0.0";
              port = cfg.listenPortMQTTExporter;
            };

            postgres = {
              enable = config.services.postgresql.enable;
              listenAddress = "0.0.0.0";
              port = cfg.listenPortPostgreSQLExporter;
              telemetryPath = "/metrics";
            };

            zfs = {
              enable = true;
              listenAddress = "0.0.0.0";
              port = cfg.listenPortZfsExporter;
            };

            # smartmontools
            smartctl = {
              enable = true;
              # devices = []; # Paths to the disks that will be monitored. Will autodiscover all disks if none given
              maxInterval = "30m"; # Interval that limits how often a disk can be queried.
              listenAddress = "0.0.0.0";
              port = cfg.listenPortSmartctlExporter;
            };

            # Blackbox
            blackbox = {
              enable = true;
              listenAddress = "0.0.0.0";
              port = cfg.listenPortBlackboxExporter;
              configFile = pkgs.writeText "blackbox.yml" ''
                modules:
                  http_2xx:
                    prober: http
                    timeout: 5s
                    http:
                      preferred_ip_protocol: "ip4"
                  icmp:
                    prober: icmp
                  tcp_connect:
                    prober: tcp
                    timeout: 5s
              '';
            };

            # Restic Exporters are dynamically created
          };

          ruleFiles =
            [
              (pkgs.writeText "system.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "system";
                      rules = [
                        {
                          # systemd service crashed
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "SystemdUnitFailed";
                          expr = ''(node_systemd_unit_state{state="failed"} == 1)'';
                          for = "0m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "systemd unit {{ $labels.name }} failed (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # CPU load is > 80%
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostHighCpuLoad";
                          expr = ''(avg by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[2m]))) > .80'';
                          for = "10m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "CPU load above 80 % (current {{ $value | humanizePercentage }}) (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # scrape target disappeared: a dead exporter or endpoint makes its
                          # metrics (and their alerts) silently blind, which nothing else catches
                          alert = "TargetDown";
                          expr = ''up == 0'';
                          for = "5m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "scrape target {{ $labels.job }} down (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Node memory is filling up (< 10% left)
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostOutOfMemory";
                          expr = ''(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < .10)'';
                          for = "2m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "less than 10 % memory available ({{ $value | humanizePercentage }} free) (instance {{ $labels.instance }})";
                          };

                        }
                        {
                          # The node is under heavy memory pressure. High rate of loading memory pages from disk.
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostMemoryUnderMemoryPressure";
                          expr = ''(rate(node_vmstat_pgmajfault[5m]) > 1000)'';
                          for = "0m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "memory pressure: {{ $value | humanize }} major page faults/s (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Clock skew detected. Clock is out of sync. Ensure NTP is configured correctly on this host.
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostClockSkew";
                          expr = ''((node_timex_offset_seconds > 0.05 and deriv(node_timex_offset_seconds[5m]) >= 0) or (node_timex_offset_seconds < -0.05 and deriv(node_timex_offset_seconds[5m]) <= 0))'';
                          for = "10m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "clock skew of {{ $value | humanize }}s detected (instance {{ $labels.instance }})";
                            description = "Clock is out of sync. Ensure NTP is configured correctly on this host.";
                          };
                        }
                        {
                          # Clock not synchronising. Ensure NTP is configured on this host.
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostClockNotSynchronising";
                          expr = ''min_over_time(node_timex_sync_status[1m]) == 0 and node_timex_maxerror_seconds >= 16'';
                          for = "2m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "clock not synchronising (instance {{ $labels.instance }})";
                            description = "Ensure NTP is configured on this host.";
                          };
                        }
                        {
                          # Physical hardware component too hot
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostPhysicalComponentTooHot";
                          expr = ''node_hwmon_temp_celsius > node_hwmon_temp_max_celsius'';
                          for = "5m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "{{ $labels.chip }} {{ $labels.sensor }} too hot ({{ $value | humanize }} °C) (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Physical node temperature alarm triggered
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostNodeOvertemperatureAlarm";
                          expr = ''((node_hwmon_temp_crit_alarm_celsius == 1) or (node_hwmon_temp_alarm == 1))'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "hardware overtemperature alarm ({{ $labels.chip }} {{ $labels.sensor }}) (instance {{ $labels.instance }})";
                          };
                        }
                      ];
                    }
                  ];
                }
              ))
              (pkgs.writeText "filesystem.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "filesystem";
                      rules = [
                        {
                          # Disk is too busy (IO wait > 80%)
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostUnusualDiskReadRate";
                          expr = ''rate(node_disk_io_time_seconds_total[5m]) > .80'';
                          for = "0m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "disk {{ $labels.device }} busy: IO time at {{ $value | humanizePercentage }} (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Disk is almost full (< 10% left)
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          # # Please add ignored mountpoints in node_exporter parameters like
                          # "--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|run)($|/)".
                          alert = "HostOutOfDiskSpace";
                          expr = ''(node_filesystem_avail_bytes{fstype!~"^(fuse.*|tmpfs|cifs|nfs|ext4|xfs|zfs)"} / node_filesystem_size_bytes < .10 and on (instance, device, mountpoint) node_filesystem_readonly == 0)'';
                          for = "2m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "disk {{ $labels.mountpoint }} almost full ({{ $value | humanizePercentage }} left) (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Swap is filling up (>80%)
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "HostSwapIsFillingUp";
                          expr = ''((1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100 > 80)'';
                          for = "2m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "swap above 80 % ({{ $value | humanize }} %) (instance {{ $labels.instance }})";
                          };

                        }
                        {
                          alert = "ZfsPoolStatusDegraded";
                          # the exporter exposes zfs_pool_health (0 = ONLINE); the previously used
                          # zfs_pool_status never existed, so this alert had never been able to fire
                          expr = ''zfs_pool_health != 0'';
                          for = "1m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "ZFS pool {{ $labels.pool }} degraded (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # HostOutOfDiskSpace excludes zfs filesystems, so pool fullness needs
                          # its own alert; CoW performance degrades on full pools, 85 % leaves
                          # room to act
                          alert = "ZfsPoolCapacityHigh";
                          expr = ''zfs_pool_allocated_bytes / (zfs_pool_allocated_bytes + zfs_pool_free_bytes) > 0.85'';
                          for = "15m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "ZFS pool {{ $labels.pool }} at {{ $value | humanizePercentage }} capacity (instance {{ $labels.instance }})";
                          };
                        }
                      ];
                    }
                  ];
                }
              ))
              (pkgs.writeText "smart.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "smart";
                      rules = [
                        {
                          # Device temperature warning on {{ $labels.instance }} drive {{ $labels.device }} over 60°C
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "SmartDeviceTemperatureWarning";
                          expr = ''(avg_over_time(smartctl_device_temperature{temperature_type="current"} [5m]) unless on (instance, device) smartctl_device_temperature{temperature_type="drive_trip"}) > 60'';
                          for = "0m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "drive {{ $labels.device }} at {{ $value | humanize }} °C (warning threshold 60 °C) (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Device temperature critical on {{ $labels.instance }} drive {{ $labels.device }} over 70°C
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "SmartDeviceTemperatureCritical";
                          expr = ''(max_over_time(smartctl_device_temperature{temperature_type="current"} [5m]) unless on (instance, device) smartctl_device_temperature{temperature_type="drive_trip"}) > 70'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "drive {{ $labels.device }} at {{ $value | humanize }} °C (critical threshold 70 °C) (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Device has a SMART status failure on {{ $labels.instance }} drive {{ $labels.device }})
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "SmartStatus";
                          expr = ''smartctl_device_smart_status != 1'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "drive {{ $labels.device }} reports SMART status failure (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Disk controller has critical warning on {{ $labels.instance }} drive {{ $labels.device }})
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "SmartCriticalWarning";
                          expr = ''smartctl_device_critical_warning > 0'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "drive {{ $labels.device }} reports controller critical warning (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Device is wearing out on {{ $labels.instance }} drive {{ $labels.device }})
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "SmartWearoutIndicator";
                          expr = ''smartctl_device_available_spare < smartctl_device_available_spare_threshold'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "drive {{ $labels.device }} wearing out ({{ $value | humanize }} % spare left) (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          alert = "SMARTFailing";
                          expr = ''smartctl_device_smart_healthy == 0'';
                          for = "5m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "drive {{ $labels.device }} reports SMART failing (instance {{ $labels.instance }})";
                          };
                        }
                      ];
                    }
                  ];
                }
              ))
              (pkgs.writeText "network.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "network";
                      rules = [
                        {
                          alert = "NodeNetworkReceiveErrors";
                          expr = ''rate(node_network_receive_errors_total[5m]) > 0'';
                          for = "2m";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "{{ $labels.device }}: {{ $value | humanize }} network receive errors/s (instance {{ $labels.instance }})";
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
                            summary = "{{ $labels.device }}: {{ $value | humanize }} network transmit errors/s (instance {{ $labels.instance }})";
                          };
                        }
                      ];
                    }
                  ];
                }
              ))
              (
                # Blackbox Exporter rules generated from the targets defined in `blackboxTargets`
                pkgs.writeText "blackbox.rules.yml" (
                  builtins.toJSON {
                    groups = [
                      {
                        name = "blackbox";
                        rules =
                          lib.map (t: {
                            alert = "BlackboxProbeFailed";
                            expr = ''probe_success{instance="${t.target}", module="${t.module}"} == 0'';
                            for = "5m";
                            labels = {
                              severity = t.labels.severityLevel or "warning";
                              service = t.labels.service or "unknown";
                              probe = t.module;
                              environment = t.labels.environment or "prod";
                              scope = t.labels.scope or "unspecified";
                            };
                            annotations = {
                              summary = "${t.labels.service}: ${t.labels.scope} Blackbox probe failed for ${t.target}";
                            };
                          }) blackboxTargets
                          ++ [
                            {
                              # the ACME renewal starts 30 days before expiry and retries daily;
                              # still being below 14 days means it has been failing for over two
                              # weeks and needs intervention (the renewal unit itself only alerts
                              # when a run fails, not when runs stop happening)
                              alert = "TlsCertificateExpiringSoon";
                              expr = ''probe_ssl_earliest_cert_expiry - time() < 14 * 24 * 3600'';
                              for = "1h";
                              labels = {
                                severity = "critical";
                              };
                              annotations = {
                                summary = "TLS certificate expires in {{ $value | humanizeDuration }} (instance {{ $labels.instance }})";
                              };
                            }
                          ];
                      }
                    ];
                  }
                )
              )
            ]
            ++ lib.optional config.services.postgresql.enable (
              pkgs.writeText "postgresql.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "postgresql";
                      rules = [
                        {
                          # Postgresql instance is down
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "PostgresqlDown";
                          expr = ''pg_up == 0'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "PostgreSQL is down (instance {{ $labels.instance }})";
                          };
                        }
                        {
                          # Postgresql exporter is showing errors. A query may be buggy in query.yaml
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          alert = "PostgresqlExporterError";
                          expr = ''pg_exporter_last_scrape_error > 0'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "PostgreSQL exporter scrape error (instance {{ $labels.instance }})";
                            description = "A query in query.yaml may be buggy.";
                          };
                        }
                        {
                          # Postgresql bloat index high (> 80%)
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          # See https://github.com/samber/awesome-prometheus-alerts/issues/289#issuecomment-1164842737
                          alert = "PostgresqlBloatIndexHigh(>80%)";
                          expr = ''pg_bloat_btree_bloat_pct > 80 and on (idxname) (pg_bloat_btree_real_size > 100000000)'';
                          for = "1h";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "index {{ $labels.idxname }} bloated ({{ $value | humanize }} %) (instance {{ $labels.instance }})";
                            description = "Execute `REINDEX INDEX CONCURRENTLY {{ $labels.idxname }};`";
                          };
                        }
                        {
                          # Postgresql bloat table high (> 80%)
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          # See https://github.com/samber/awesome-prometheus-alerts/issues/289#issuecomment-1164842737
                          alert = "PostgresqlBloatTableHigh(>80%)";
                          expr = ''pg_bloat_table_bloat_pct > 80 and on (relname) (pg_bloat_table_real_size > 200000000)'';
                          for = "1h";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "table {{ $labels.relname }} bloated ({{ $value | humanize }} %) (instance {{ $labels.instance }})";
                            description = "Execute `VACUUM {{ $labels.relname }};`";
                          };
                        }
                        {
                          # Postgresql invalid index
                          # from https://samber.github.io/awesome-prometheus-alerts/rules
                          # See https://github.com/samber/awesome-prometheus-alerts/issues/289#issuecomment-1164842737
                          alert = "PostgresqlInvalidIndex";
                          expr = ''pg_general_index_info_pg_relation_size{indexrelname=~".*ccnew.*"}'';
                          for = "6h";
                          labels = {
                            severity = "warning";
                          };
                          annotations = {
                            summary = "invalid index {{ $labels.indexrelname }} (instance {{ $labels.instance }})";
                            description = "Leftover ccnew index from an interrupted REINDEX CONCURRENTLY.";
                          };
                        }
                      ];
                    }
                  ];
                }
              )
            )
            ++ lib.optional cfg.enableTestAlert (
              pkgs.writeText "test.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "test";
                      rules = [
                        {
                          alert = "ManualTestAlert";
                          expr = ''vector(1)'';
                          for = "0m";
                          labels = {
                            severity = "critical";
                          };
                          annotations = {
                            summary = "Test alert";
                            description = "Triggered manually for testing.";
                          };
                        }
                      ];
                    }
                  ];
                }
              )
            );
        };

      # If Grafana is enabled, configure it to use Prometheus and Loki as a data source and add dashboards
      services.grafana = lib.mkIf config.services.grafana.enable {
        settings = {
          security.secret_key = lib.mkForce "$__file{${cfg.grafanaSecretKeyFile}}";
          # Admin password is read from a file so it survives a Grafana state reset
          # (Grafana applies it when the admin user is first created).
          security.admin_password = lib.mkForce "$__file{${cfg.grafanaAdminPasswordFile}}";
          # The NixOS module disables the Grafana and plugin update checks by
          # default -- except the plugin check when declarativePlugins is unset.
          # Plugins only ever change through nixpkgs here, so the 10-minute check
          # is pure log noise and an unnecessary call to grafana.com.
          analytics.check_for_plugin_updates = false;
        };
        provision = {
          enable = true;
          datasources.settings.datasources =
            [
              {
                name = "Prometheus";
                type = "prometheus";
                uid = "prometheus_12121212123";
                access = "proxy";
                url = "http://127.0.0.1:${toString config.services.prometheus.port}";
                # actual scrape interval (Prometheus default 1m); without it Grafana assumes 15s and
                # $__rate_interval may pick windows with fewer than two samples, yielding empty panels
                jsonData.timeInterval = "1m";
              }
            ]
            # lib.optionals (not lib.optional): the list is appended as-is,
            # lib.optional would nest it as a single list-typed element
            ++ lib.optionals config.services.loki.enable [
              {
                name = "Loki";
                type = "loki";
                uid = "loki"; # pinned so provisioned dashboards can reference it stably
                access = "proxy";
                url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
              }
            ];
          dashboards.settings.providers = [
            {
              name = "Prometheus";
              folder = "Prometheus";
              # Pin the folder UID so the direct dashboards URL stays stable across
              # rebuilds. Requires a clean Grafana state (no pre-existing folder of
              # the same name), otherwise Grafana matches by name and ignores this.
              folderUid = grafanaDashboardFolderUid;
              type = "file";
              # disableDeletion = false;
              # allowUiUpdates = true;
              # updateIntervalSeconds = 86400;
              options.path = lib.sources.sourceFilesBySuffices ./grafana-dashboards [ ".json" ];
            }
          ];
        };
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

      # Grafana
      services.caddy.virtualHosts."${cfgSubServiceTwo.url}" = lib.mkIf config.services.grafana.enable {
        useACMEHost = homelab.baseDomain;
        extraConfig = ''
          redir / /dashboards/f/${grafanaDashboardFolderUid} 302
          reverse_proxy http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}
        '';
      };
    })
    (lib.mkIf (cfg.fritzboxExporter.enable && cfg.enable) {
      homelab.services.fritzbox-exporter = {
        enable = true;
        prometheus.listenPort = cfg.fritzboxExporter.listenPort;
      };
    })
  ];
}
