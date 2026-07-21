{ config, lib, ... }:
let
  service = "loki";
  cfg = config.homelab.services.${service};

  # Alloy pipeline stages forcing level="info" for container units whose logs
  # carry no level tag (declared by the owning service modules via
  # untaggedContainerLogUnits). Rendered before the tag-parsing stage so a
  # tagged line still wins.
  untaggedLevelStages = lib.optionalString (cfg.untaggedContainerLogUnits != [ ]) (
    ''
      // These units log without level tags, so podman's stream priority would
      // leave every stderr line at "err"; force "info" instead. Declared by the
      // owning service modules via homelab.services.loki.untaggedContainerLogUnits.
    ''
    + lib.concatMapStrings (unit: ''
      stage.match {
        selector = "{unit=\"${unit}\"}"

        stage.static_labels {
          values = { level = "info" }
        }
      }
    '') cfg.untaggedContainerLogUnits
  );
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    # Intentionally no stateDir option: log data is high-churn telemetry with its
    # own retention, so it is excluded from the restic backup (the backup module
    # only picks up services that define a stateDir).
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 3100;
      description = "HTTP port of Loki (API, metrics and readiness probe)";
    };
    listenPortAlloy = lib.mkOption {
      type = lib.types.int;
      default = 12345;
      description = "HTTP port of Grafana Alloy (UI, metrics and readiness probe)";
    };
    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "90d";
      description = "How long Loki keeps log data before the compactor deletes it";
    };
    untaggedContainerLogUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "podman-changedetection-io-playwright.service" ];
      description = "systemd units of podman containers whose logs carry no level tag. Podman flags all container stderr output as priority \"err\", so the level label of these units is forced to \"info\" instead. Meant to be set by the service module owning the container.";
    };
    prometheus.scrapeConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        job_name = "${service}";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.listenPort}" ];
          }
        ];
      };
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${toString cfg.listenPort}/ready" "internal")
          (blackbox.mkHttpTarget "alloy" "http://127.0.0.1:${toString cfg.listenPortAlloy}/-/ready"
            "internal"
          )
        ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.loki = {
      enable = true;
      # Loki has no web UI; it is queried through Grafana (provisioned as data
      # source in the prometheus module), so no Caddy vhost and no homepage entry.
      configuration = {
        # see https://grafana.com/docs/loki/latest/configure/ for reference
        auth_enabled = false;
        analytics.reporting_enabled = false;

        server = {
          # loopback only: Loki is queried exclusively by the local Grafana and Prometheus
          http_listen_address = "127.0.0.1";
          http_listen_port = cfg.listenPort;
          grpc_listen_address = "127.0.0.1"; # gRPC is only used internally within the single binary
        };

        common = {
          # base path for everything not set explicitly below, most importantly the
          # ingester write-ahead log (<path_prefix>/wal); keeps all local state under
          # the directory managed by the NixOS module instead of relying on the
          # unit's WorkingDirectory for relative default paths
          path_prefix = config.services.loki.dataDir;
          # address the internal components (query frontend, ring members) advertise
          # to each other; must be loopback because the gRPC server only listens
          # there -- otherwise the querier dials the LAN IP and every read hangs
          instance_addr = "127.0.0.1";
          replication_factor = 1; # single instance: store every log line once, no replicas
          # the ring coordinates multiple Loki instances; with a single instance it
          # only ever contains the process itself
          ring.kvstore.store = "inmemory"; # keep the ring in process memory instead of consul/etcd or memberlist gossip
          storage.filesystem = {
            chunks_directory = "${config.services.loki.dataDir}/chunks"; # the actual log data
            rules_directory = "${config.services.loki.dataDir}/rules"; # ruler storage (no alerting rules defined yet)
          };
        };

        # list of time periods, each declaring the index schema and store used from
        # its start date on. Loki rejects log lines with timestamps before the first
        # `from`; once data has been ingested this entry must never be edited --
        # schema migrations are done by appending a new entry with a future date.
        schema_config.configs = [
          {
            from = "2024-01-01"; # any date before the first ingested log line
            store = "tsdb"; # current index implementation (successor of boltdb-shipper)
            object_store = "filesystem"; # chunks on local disk, no object storage
            schema = "v13"; # schema version required for tsdb
            index = {
              prefix = "index_";
              period = "24h"; # one index file per day, the only valid value for tsdb
            };
          }
        ];

        limits_config.retention_period = cfg.retentionPeriod;

        compactor = {
          # compacts index shards for performance
          working_directory = "${config.services.loki.dataDir}/compactor";
          retention_enabled = true; # the compactor is also what actually deletes data older than retention_period
          delete_request_store = "filesystem"; # required when retention_enabled
        };
      };
    };

    # Grafana Alloy ships the systemd journal to Loki (successor of the
    # deprecated Promtail). The NixOS module already grants journal read access
    # via SupplementaryGroups = [ "systemd-journal" ].
    services.alloy = {
      enable = true;
      extraFlags = [
        "--server.http.listen-addr=127.0.0.1:${toString cfg.listenPortAlloy}" # Alloy UI and metrics, loopback only
        "--disable-reporting" # no usage telemetry to Grafana Labs
      ];
    };

    environment.etc."alloy/config.alloy".text = ''
      // Keep systemd unit, log level and hostname as Loki labels
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "host"
        }
      }

      // Read the systemd journal; on first start entries up to max_age old are
      // backfilled, afterwards Alloy continues from its stored position
      loki.source.journal "journal" {
        max_age       = "12h"
        relabel_rules = loki.relabel.journal.rules
        labels        = { job = "systemd-journal" }
        forward_to    = [loki.process.container_level.receiver]
      }

      // Podman's journald log driver flags every stderr line of a container as
      // priority "err" no matter what the line actually says, so the level label
      // is wrong for containers that write their logs to stderr. For lines from
      // podman units that carry a level tag in the message (e.g. "[INFO]"),
      // overwrite the level label with that tag; lines without a tag keep the
      // stream-based level so real errors still surface.
      loki.process "container_level" {
        forward_to = [loki.write.local.receiver]

      ${untaggedLevelStages}
        stage.match {
          selector = "{unit=~\"podman-.+\"} |~ \"\\\\[(?i)(DEBUG|INFO|NOTICE|WARNING|WARN|ERROR|CRITICAL|FATAL)\\\\]\""

          stage.regex {
            expression = "\\[(?P<extracted_level>(?i)(DEBUG|INFO|NOTICE|WARNING|WARN|ERROR|CRITICAL|FATAL))\\]"
          }
          stage.template {
            source   = "extracted_level"
            template = "{{ lower .Value }}"
          }
          // normalize to the journald priority keywords used by all other units
          stage.template {
            source   = "extracted_level"
            template = "{{ if eq .Value \"error\" }}err{{ else if eq .Value \"warn\" }}warning{{ else if eq .Value \"critical\" }}crit{{ else if eq .Value \"fatal\" }}crit{{ else }}{{ .Value }}{{ end }}"
          }
          stage.labels {
            values = { level = "extracted_level" }
          }
        }
      }

      // Push to the local Loki instance
      loki.write "local" {
        endpoint {
          url = "http://127.0.0.1:${toString cfg.listenPort}/loki/api/v1/push"
        }
      }
    '';

    # Alloy's own metrics; the Loki job itself is added through the
    # prometheus.scrapeConfig option above like for the other services.
    services.prometheus.scrapeConfigs = [
      {
        job_name = "alloy";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.listenPortAlloy}" ];
          }
        ];
      }
    ];
  };
}
