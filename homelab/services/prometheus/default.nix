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

  # --- Restic Exporter Dynamic Configuration ---
  # Get all configured restic backup jobs
  resticBackups = config.services.restic.backups;

  # Generate an attribute set for each restic exporter
  resticExporters = builtins.listToAttrs (
    builtins.genList (
      i:
      let
        name = builtins.elemAt (builtins.attrNames resticBackups) i;
        backup = builtins.getAttr name resticBackups;
      in
      {
        name = "restic-exporter-${name}";
        value = {
          port = cfg.listenPortResticExporterBase + i;
          repository = backup.repository;
          passwordFile = backup.passwordFile;
          environmentFile =
            if builtins.hasAttr "environmentFile" backup then backup.environmentFile else null;
          repositoryFile = if builtins.hasAttr "repositoryFile" backup then backup.repositoryFile else null;
        };
      }
    ) (builtins.length (builtins.attrNames resticBackups))
  );

  # Generate the systemd services for each exporter
  resticExporterServices = lib.mapAttrs' (
    name: exporterConfig:
    let
      serviceName = "restic-exporter-${name}";
    in
    lib.nameValuePair serviceName {
      # based on https://github.com/NixOS/nixpkgs/blob/0d00f23f023b7215b3f1035adb5247c8ec180dbc/nixos/modules/services/monitoring/prometheus/exporters.nix
      # and https://github.com/NixOS/nixpkgs/blob/0d00f23f023b7215b3f1035adb5247c8ec180dbc/nixos/modules/services/monitoring/prometheus/exporters/restic.nix
      description = "Restic Exporter for ${name} repository";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        LISTEN_ADDRESS = "0.0.0.0";
        LISTEN_PORT = toString exporterConfig.port;
        REFRESH_INTERVAL = toString 60;
        RESTIC_CACHE_DIR = "$CACHE_DIRECTORY";
      };
      script = ''
        export RESTIC_REPOSITORY=${
          if exporterConfig.repositoryFile != null then
            "$(cat $CREDENTIALS_DIRECTORY/RESTIC_REPOSITORY)"
          else
            "${exporterConfig.repository}"
        }
        export RESTIC_PASSWORD_FILE=$CREDENTIALS_DIRECTORY/RESTIC_PASSWORD_FILE
        ${pkgs.prometheus-restic-exporter}/bin/restic-exporter.py'';
      serviceConfig =
        {
          User = "restic-exporter";
          Group = "restic-exporter";
          Restart = "on-failure";
          RestartSec = 10;
          WorkingDirectory = lib.mkDefault /tmp;
          CacheDirectory = "restic-exporter-${name}";
          PrivateTmp = true;
          # Hardening
          CapabilityBoundingSet = lib.mkDefault [ "" ];
          DeviceAllow = [ "" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = lib.mkDefault true;
          ProtectClock = lib.mkDefault true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = lib.mkDefault "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        }
        // lib.optionalAttrs (exporterConfig.environmentFile != null) {
          # Load environment variables (e.g., for S3 credentials) from the specified file.
          EnvironmentFile = exporterConfig.environmentFile;
        }
        // {
          LoadCredential =
            [ "RESTIC_PASSWORD_FILE:${exporterConfig.passwordFile}" ]
            ++ lib.optional (exporterConfig.repositoryFile != null) [
              "RESTIC_REPOSITORY:${exporterConfig.repositoryFile}"
            ];
        };
    }
  ) resticExporters;

  # Generate the restic scrape configs for prometheus
  resticScrapeConfigs = lib.mapAttrsToList (name: exporterConfig: {
    job_name = "restic-exporter-${name}";
    static_configs = [
      {
        targets = [ "localhost:${toString exporterConfig.port}" ];
      }
    ];
  }) resticExporters;
in
{
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
    listenPortResticExporterBase = lib.mkOption {
      type = lib.types.int;
      description = "Define a starting port for the dynamically created restic exporters. Each defined restic.backup will increment by 1.";
      default = 9753;
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
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "prometheus" "localhost:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTargetCritical "alertmanager" "localhost:${toString cfg.listenPort}" "internal")
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
      default = "Alertmanager";
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
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.optionalAttrs (lib.length (lib.attrNames resticBackups) > 0) {
      "restic-exporter" = { };
    };
    users.users = lib.optionalAttrs (lib.length (lib.attrNames resticBackups) > 0) {
      "restic-exporter" = {
        isSystemUser = true;
        createHome = lib.mkForce false;
        description = "Runs the restic-exporters";
        group = "restic-exporter";
      };
    };
    environment.systemPackages = lib.optional (
      lib.length (lib.attrNames resticBackups) > 0
    ) pkgs.prometheus-restic-exporter;

    # Add the generated systemd services for the restic exporters
    systemd.services = lib.optionalAttrs (
      lib.length (lib.attrNames resticBackups) > 0
    ) resticExporterServices;

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
          ]
          ++ resticScrapeConfigs;

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
                    # only this is working
                    # message = ''
                    #   {{ range .Alerts }}
                    #   🔔 Alert: {{ .Labels.alertname }}
                    #   {{ end }}
                    # '';
                    # not working
                    # message = ''
                    #   {{ .Status | toUpper }} {{ if eq .Status "firing" }}🔴{{ else }}🟢{{ end }}

                    #   {{ range .Alerts }}
                    #   {{ .Labels.alertname | default "Unnamed Alert" }}

                    #   🧩 Service: {{ .Labels.service | default "unknown" }}
                    #   🏷️ Scope: {{ .Labels.scope | default "unspecified" }}
                    #   🏷️ Severity: {{ .Labels.severity | default "warning" }}
                    #   🌍 Environment: {{ .Labels.environment | default "prod" }}
                    #   📍 Instance: {{ .Labels.instance | default "n/a" }}
                    #   🧪 Probe: {{ .Labels.probe | default "n/a" }}

                    #   📝 Summary: {{ .Annotations.summary | default "n/a" }}
                    #   📖 Description: {{ .Annotations.description | default "n/a" }}
                    #   {{ end }}
                    # '';
                    # not working
                    # message = ''
                    #   {{ define "telegram.default.message" }}
                    #   {{ if eq .Status "firing" }}
                    #   {{ if eq .Labels.severity "critical" }}🔴 *Alert:* {{ .Labels.alertname }}
                    #   {{ else if eq .Labels.severity "warning" }}🟠 *Alert:* {{ .Labels.alertname }}
                    #   {{ else }}⚪️ *Alert:* {{ .Labels.alertname }}
                    #   {{ end }}
                    #   *Status:* 🔥 FIRING
                    #   *Severity:* {{ if eq .Labels.severity "critical" }}🔴 **{{ .Labels.severity | title }}**{{ else if eq .Labels.severity "warning" }}🟠 **{{ .Labels.severity | title }}**{{ else }}⚪️ **{{ .Labels.severity | title }}**{{ end }}
                    #   {{ else if eq .Status "resolved" }}
                    #   {{ if eq .Labels.severity "critical" }}🟢 *🚌 TRANSPORT Alert:* {{ .Labels.alertname }}
                    #   {{ else if eq .Labels.severity "warning" }}🟢 *🚌 TRANSPORT
                    #   Alert:* {{ .Labels.alertname }}
                    #   {{ else }}⚪️ *Alert:* {{ .Labels.alertname }}
                    #   {{ end }}
                    #   *Status:* ✅ RESOLVED
                    #   *Severity:* {{ if eq .Labels.severity "critical" }}🟢 **{{ .Labels.severity | title }}**{{ else if eq .Labels.severity "warning" }}🟢 **{{ .Labels.severity | title }}**{{ else }}⚪️ **{{ .Labels.severity | title }}**{{ end }}
                    #   {{ end }}
                    #   {{ range .Alerts }}
                    #   *Instance:* {{ .Labels.instance }}
                    #     - *Title:* {{ .Annotations.summary }}
                    #     - *Description:* {{ .Annotations.description }}
                    #   {{ end }}
                    #   {{ end }}
                    # '';
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
                          summary = "Host systemd service crashed (instance {{ $labels.instance }})";
                          description = "systemd service crashed\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host high CPU load (instance {{ $labels.instance }})";
                          description = "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                        # Node memory is filling up (< 10% left)
                        # from https://samber.github.io/awesome-prometheus-alerts/rules
                        alert = "HostOutOfMemory";
                        expr = ''(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < .10)'';
                        for = "2m";
                        labels = {
                          severity = "warning";
                        };
                        annotations = {
                          summary = "Host out of memory (instance {{ $labels.instance }})";
                          description = "Node memory is filling up (< 10% left)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host memory under memory pressure (instance {{ $labels.instance }})";
                          description = "The node is under heavy memory pressure. High rate of loading memory pages from disk.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host clock skew (instance {{ $labels.instance }})";
                          description = "Clock skew detected. Clock is out of sync. Ensure NTP is configured correctly on this host.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host clock not synchronising (instance {{ $labels.instance }})";
                          description = "Clock not synchronising. Ensure NTP is configured on this host.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host physical component too hot (instance {{ $labels.instance }})";
                          description = "Physical hardware component too hot\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host node overtemperature alarm (instance {{ $labels.instance }})";
                          description = "Physical node temperature alarm triggered\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host unusual disk read rate (instance {{ $labels.instance }})";
                          description = "Disk is too busy (IO wait > 80%)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host out of disk space (instance {{ $labels.instance }})";
                          description = "Disk is almost full (< 10% left)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Host swap is filling up (instance {{ $labels.instance }})";
                          description = "Swap is filling up (>80%)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                        };

                      }
                      {
                        alert = "ZfsPoolStatusDegraded";
                        expr = ''zfs_pool_status != 0'';
                        for = "1m";
                        labels = {
                          severity = "warning";
                        };
                        annotations = {
                          summary = "ZFS pool status degraded (instance {{ $labels.instance }})";
                          description = "ZFS pool status is degraded. Check the ZFS pool status on the host.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "SMART device temperature warning (instance {{ $labels.instance }})";
                          description = "Device temperature warning on {{ $labels.instance }} drive {{ $labels.device }} over 60°C\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "SMART device temperature critical (instance {{ $labels.instance }})";
                          description = "Device temperature critical on {{ $labels.instance }} drive {{ $labels.device }} over 70°C\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "SMART status (instance {{ $labels.instance }})";
                          description = "Device has a SMART status failure on {{ $labels.instance }} drive {{ $labels.device }})\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "SMART critical warning (instance {{ $labels.instance }})";
                          description = "Disk controller has critical warning on {{ $labels.instance }} drive {{ $labels.device }})\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "SMART Wearout Indicator (instance {{ $labels.instance }})";
                          description = "Device is wearing out on {{ $labels.instance }} drive {{ $labels.device }})\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "SMART failing (instance {{ $labels.instance }})";
                          description = "SMART failure on disk {{ $labels.device }} ({{ $labels.instance }})";
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
              }
            ))
            (
              # Blackbox Exporter rules generated from the targets defined in `blackboxTargets`
              pkgs.writeText "blackbox.rules.yml" (
                builtins.toJSON {
                  groups = [
                    {
                      name = "blackbox";
                      rules = lib.map (t: {
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
                          description = "Blackbox module `${t.module}` reported failure on `${t.target}`.";
                        };
                      }) blackboxTargets;
                    }
                  ];
                }
              )
            )
          ]
          ++ lib.optional config.services.caddy.enable (
            pkgs.writeText "caddy.rules.yml" (
              builtins.toJSON {
                groups = [
                  {
                    name = "caddy";
                    rules = [
                      {
                        # All Caddy reverse proxies are down
                        # from https://samber.github.io/awesome-prometheus-alerts/rules
                        alert = "CaddyReverseProxyDown";
                        expr = ''count(caddy_reverse_proxy_upstreams_healthy) by (upstream) == 0'';
                        for = "0m";
                        labels = {
                          severity = "critical";
                        };
                        annotations = {
                          summary = "Caddy Reverse Proxy Down (instance {{ $labels.instance }})";
                          description = "All Caddy reverse proxies are down\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                        };
                      }
                      {
                        # Caddy service 4xx error rate is above 5%
                        # from https://samber.github.io/awesome-prometheus-alerts/rules
                        alert = "CaddyHighHttp4xxErrorRateService";
                        expr = ''sum(rate(caddy_http_request_duration_seconds_count{code=~"4.."}[3m])) by (instance) / sum(rate(caddy_http_request_duration_seconds_count[3m])) by (instance) * 100 > 5'';
                        for = "1m";
                        labels = {
                          severity = "critical";
                        };
                        annotations = {
                          summary = "Caddy high HTTP 4xx error rate service (instance {{ $labels.instance }})";
                          description = "Caddy service 4xx error rate is above 5%\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                        };
                      }
                      {
                        # Caddy service 5xx error rate is above 5%
                        # from https://samber.github.io/awesome-prometheus-alerts/rules
                        alert = "CaddyHighHttp5xxErrorRateService";
                        expr = ''sum(rate(caddy_http_request_duration_seconds_count{code=~"5.."}[3m])) by (instance) / sum(rate(caddy_http_request_duration_seconds_count[3m])) by (instance) * 100 > 5'';
                        for = "1m";
                        labels = {
                          severity = "critical";
                        };
                        annotations = {
                          summary = "Caddy high HTTP 5xx error rate service (instance {{ $labels.instance }})";
                          description = "Caddy service 5xx error rate is above 5%\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                        };
                      }
                    ];
                  }
                ];
              }
            )
          )
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
                          summary = "Postgresql down (instance {{ $labels.instance }})";
                          description = "Postgresql instance is down\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Postgresql exporter error (instance {{ $labels.instance }})";
                          description = "Postgresql exporter is showing errors. A query may be buggy in query.yaml\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Postgresql bloat index high (> 80%) (instance {{ $labels.instance }})";
                          description = "The index {{ $labels.idxname }} is bloated. You should execute `REINDEX INDEX CONCURRENTLY {{ $labels.idxname }};`\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Postgresql bloat table high (> 80%) (instance {{ $labels.instance }})";
                          description = "The table {{ $labels.relname }} is bloated. You should execute `VACUUM {{ $labels.relname }};`\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          summary = "Postgresql invalid index (instance {{ $labels.instance }})";
                          description = "Postgresql invalid index (instance {{ $labels.instance }})";
                        };
                      }
                    ];
                  }
                ];
              }
            )
          )
          ++ lib.optional (lib.length (lib.attrNames resticBackups) > 0) (
            pkgs.writeText "restic.rules.yml" (
              builtins.toJSON {
                groups = [
                  {
                    name = "restic";
                    rules = [
                      {
                        alert = "ResticBackupCheckFailed";
                        expr = ''restic_check_status{job=~"restic-exporter-.*"} == 0'';
                        for = "10m";
                        labels = {
                          severity = "critical";
                        };
                        annotations = {
                          summary = "Restic backup check failed for {{ $labels.job }}";
                          description = "The restic backup check for job {{ $labels.job }} on instance {{ $labels.instance }} has failed.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                        };
                      }
                      {
                        alert = "ResticBackupFailed";
                        expr = ''restic_backup_last_status{job=~"restic-exporter-.*", result="failed"} == 1'';
                        for = "10m";
                        labels = {
                          severity = "critical";
                        };
                        annotations = {
                          summary = "Restic backup failed for {{ $labels.job }}";
                          description = "The restic backup job {{ $labels.job }} on instance {{ $labels.instance }} has failed.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
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
                          description = "Triggered manually for testing (instance {{ $labels.instance }})";
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
            }
          ]
          ++ lib.optional config.services.loki.enable [
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
            }
          ];
        dashboards.settings.providers = [
          {
            name = "Prometheus";
            folder = "Prometheus";
            uid = "prometheus_folder";
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
        redir / /dashboards/f/beui7s12o7400f 302
        reverse_proxy http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}
      '';
    };
  };
}
