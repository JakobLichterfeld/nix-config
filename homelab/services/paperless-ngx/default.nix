{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  service = "paperless";
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
      default = "/var/lib/${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "127.0.0.1";
      description = "IP address where the web interface is exposed";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      description = "Port where the web interface is exposed";
      default = 28981;
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory where the media files are stored.
      This will be backed up via the 'config.homelab.services.backup' service.";
      default = "${homelab.mounts.merged}/Paperless/Documents";
    };
    backup.additionalPathsToBackup = import ../../../lib/options/backupAdditionalPathsToBackup.nix {
      inherit lib;
      additionalPathsToBackup = [ cfg.mediaDir ];
    };
    consumptionDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory where documents are placed for Paperless-ngx to consume, so that they can be processed and indexed.
      The files in this directory will be moved to the media directory after processing.";
      default = "${homelab.mounts.fast}/Paperless/Import"; # we use the cache as the files will be moved to the media directory after processing, so no need for mergerfs, and this directory is excluded from mover as well
    };
    passwordFile = lib.mkOption {
      type = lib.types.path;
      description = "File with admin password to the Paperless-ngx web interface";
      default = config.age.secrets.paperlessPassword.path;
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. PAPERLESS_SECRET_KEY";
      type = with lib.types; nullOr path;
      default = config.age.secrets.paperlessEnv.path;
      example = lib.literalExpression ''
          pkgs.writeText "paperless-secret-environment" '''
          PAPERLESS_SECRET_KEY=<secret>
        '''
      '';
    };
    ocrLanguage = lib.mkOption {
      type = lib.types.str;
      default = "deu+eng";
      description = "OCR language for Paperless-ngx. See https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html for valid values.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Paperless-ngx";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Document management system";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "paperless.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };

    prometheus = {
      listenPort = lib.mkOption {
        type = lib.types.int;
        default = 5555;
        description = "Port where the Prometheus monitoring for Paperless-ngx via Flower web interface is exposed";
      };
      scrapeConfig = lib.mkOption {
        type = lib.types.attrs;
        default = {
          job_name = "${service}";
          metrics_path = "/metrics"; # Flower exposes metrics here
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.prometheus.listenPort}" ];
            }
          ];
        };
        description = "Prometheus scrape configuration for Paperless-ngx via Flower.";
      };
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
    services.${service} = {
      enable = true;
      package = pkgsUnstable.paperless-ngx;
      address = cfg.listenAddress;
      port = cfg.listenPort;
      passwordFile = cfg.passwordFile;

      database.createLocally = true;
      dataDir = cfg.stateDir;

      mediaDir = cfg.mediaDir;
      consumptionDir = cfg.consumptionDir;
      consumptionDirIsPublic = true; # everyone can write to the consumption directory, so that files can be placed there for processing directly by the scanner for example

      environmentFile = cfg.secretEnvironmentFile;

      settings = {
        PAPERLESS_URL = "https://${cfg.url}";
        PAPERLESS_TIME_ZONE = homelab.timeZone;
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          ".DS_Store/*"
          "desktop.ini"
          "Thumbs.db"
        ];
        PAPERLESS_CONSUMER_RECURSIVE = true; # Enable recursive watching of the consumption directory.
        PAPERLESS_FILENAME_FORMAT = "{{ owner_username }}/{{ correspondent }}/{{ created }} {{ title }}";
        PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = true; # Tells paperless to replace placeholders in PAPERLESS_FILENAME_FORMAT that would resolve to 'none' to be omitted from the resulting filename. This also holds true for directory names.
        PAPERLESS_AUDIT_LOG_ENABLED = true; # Enables the audit trail for documents, document types, correspondents, and tags.
        PAPERLESS_OCR_SKIP_ARCHIVE_FILE = "never"; # Never skip creating an archived version.
        PAPERLESS_OCR_DESKEW = true; # Tells paperless to correct skewing (slight rotation of input images mainly due to improper scanning)
        PAPERLESS_OCR_ROTATE_PAGES = true; # Tells paperless to correct page rotation (90°, 180° and 270° rotation).
        PAPERLESS_OCR_OUTPUT_TYPE = "pdfa"; # Convert PDF documents into PDF/A-2b documents, which is a subset of the entire PDF specification and meant for storing documents long term. Remember that paperless also keeps the original input file as well as the archived version.
        PAPERLESS_OCR_LANGUAGE = cfg.ocrLanguage;
        PAPERLESS_OCR_USER_ARGS = {
          # see https://ocrmypdf.readthedocs.io/en/latest/api.html#reference for available options
          optimize = 1; # Enables lossless optimizations, such as transcoding images to more efficient formats. Also compress other uncompressed objects in the PDF and enables the more efficient “object streams” within the PDF
          pdfa_image_compression = "lossless"; # use lossless compression for images in the PDF/A output
          invalidate_digital_signatures = true; # invalidate_digital_signatures, needed to import docs with digital signature.
          # As paperless keeps the original anyways we can ignore this error.
          # See: https://github.com/paperless-ngx/paperless-ngx/discussions/4047
        };
        # enable Celery Monitoring via Flower to export metrics for Prometheus
        # see https://docs.paperless-ngx.com/advanced_usage/#celery-monitoring
        PAPERLESS_ENABLE_FLOWER = config.services.prometheus.enable;
      };
    };

    # Manually define a systemd service for Flower, as the NixOS module does not provide an option for it.
    # This service is only enabled if prometheus is enabled on the host.
    systemd.services.paperless-prometheus-via-flower = lib.mkIf config.services.prometheus.enable {
      description = "Flower service for Paperless-ngx Prometheus metrics";
      after = [
        "network.target"
        "redis-paperless.service"
        "paperless-consumer.service"
      ];
      wants = [ "paperless-consumer.service" ]; # Flower monitors the consumer
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = config.services.${service}.user;
        Group = config.services.${service}.user;
        WorkingDirectory = cfg.stateDir;
        ReadWritePaths = [
          cfg.stateDir
          cfg.mediaDir
          cfg.consumptionDir
        ];
        SupplementaryGroups = "redis-paperless";
        EnvironmentFile = cfg.secretEnvironmentFile;
        Environment =
          lib.mapAttrsToList (n: v: "${n}=${builtins.toJSON v}") config.services.paperless.settings
          ++ [
            "PAPERLESS_DATA_DIR=${cfg.stateDir}" # otherwise flower tries to write to nix-store
          ];
        CapabilityBoundingSet = "";
        DeviceAllow = [
          "/dev/null rw"
          "/dev/urandom r"
        ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateNetwork = false; # as we need to connect to the /metrics endpoint
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        Restart = "on-failure";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        Slice = "system-paperless.slice";
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "@setuid"
          "@keyring"
        ];
        UMask = "0066";
        # We call flower directly. The address and port are passed as arguments.
        # The broker URL points to the redis socket created by the paperless service.
        ExecStart = ''
          ${config.services.${service}.package}/bin/celery \
            --app paperless \
            --broker=redis+socket:///run/redis-paperless/redis.sock \
            flower \
            --address=127.0.0.1 \
            --port=${toString cfg.prometheus.listenPort} \
            --prometheus_metrics
        '';
        StandardOutput = "journal";
        StandardError = "journal";
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
