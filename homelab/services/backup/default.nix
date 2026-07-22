{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "backup";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in

{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable backups for application state folders";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up, in this case the database dumps";
      default = "/var/backup";
    };
    paperless.enable = lib.mkOption {
      type = lib.types.bool;
      description = "Enable backups for Paperless documents to S3";
      default = hl.services.paperless.enable;
    };
    passwordFile = lib.mkOption {
      description = "File with password to the Restic repository";
      type = lib.types.path;
    };
    s3.enable = lib.mkOption {
      description = "Enable S3 backups for application state directories";
      default = false;
      type = lib.types.bool;
    };
    s3.url = lib.mkOption {
      description = "URL of the S3-compatible endpoint to send the backups to";
      default = "";
      type = lib.types.str;
    };
    s3.environmentFile = lib.mkOption {
      description = "File with S3 credentials";
      type = lib.types.path;
      example = lib.literalExpression ''
        pkgs.writeText "restic-s3-environment" '''
          AWS_DEFAULT_REGION=eu-central-1
          AWS_ACCESS_KEY_ID=
          AWS_SECRET_ACCESS_KEY=
        '''
      '';
    };
    s3.useTarball = lib.mkOption {
      description = "Whether to bundle all backup files into a single tarball before uploading. This drastically reduces the number of S3 API transactions, which is necessary for services with a low free transaction limit. The downside is less granular deduplication.";
      default = false;
      type = lib.types.bool;
    };
    local.enable = lib.mkOption {
      description = "Enable local backups for application state directories";
      default = false;
      type = lib.types.bool;
    };
    local.targetDir = lib.mkOption {
      description = "Target path for local Restic backups";
      default = "${hl.mounts.merged}/Backups/Restic";
      type = lib.types.path;
    };
    local.listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8000;
      description = "HTTP Port on which restic server runs.";
    };
    prometheus.scrapeConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        job_name = "rest server";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.local.listenPort}" ];
          }
        ];
      };
    };
    listenPortResticExporterBase = lib.mkOption {
      type = lib.types.int;
      description = "Define a starting port for the dynamically created restic exporters. Each defined restic.backup will increment by 1.";
      default = 9753;
    };
  };
  config =
    let
      enabledServices = lib.attrsets.filterAttrs (
        name: value: value ? enable && value.enable
      ) hl.services;

      enabledServicesWithStateDir = lib.attrsets.filterAttrs (
        name: value: value ? stateDir
      ) enabledServices;

      enabledServicesWithAdditionalPathsToBackup = lib.attrsets.filterAttrs (
        name: value: value ? "backup" && value.backup ? "additionalPathsToBackup"
      ) enabledServices;

      additionalPathsToBackup = lib.flatten (
        lib.attrsets.mapAttrsToList (
          name: value: value.backup.additionalPathsToBackup
        ) enabledServicesWithAdditionalPathsToBackup
      );

      # read the 'servicesToManage' lists from all enabled services
      # and merge them into a single flat list.
      serviceNamesToManage = lib.flatten (
        lib.attrsets.mapAttrsToList (
          name: value:
          if (value ? "backup" && value.backup ? "servicesToManage" && value.enable) then
            value.backup.servicesToManage
          else
            [ ]
        ) hl.services
      );
      servicesToStopBeforeBackupAndStartAfterBackupStr = lib.concatStringsSep " " serviceNamesToManage;

      # Commands to stop and start services
      stopServicesCmd = "systemctl stop ${servicesToStopBeforeBackupAndStartAfterBackupStr}";
      startServicesCmd = "systemctl start ${servicesToStopBeforeBackupAndStartAfterBackupStr}";
      trapCmd = "trap '${startServicesCmd}' EXIT";

      preBackupCommandsToStopServicesAndStartAfter = lib.optionalString (serviceNamesToManage != [ ]) ''
        ${stopServicesCmd}
        ${trapCmd}
      '';

      stateDirsList = lib.attrsets.mapAttrsToList (
        name: value: lib.attrsets.attrByPath [ name "stateDir" ] false enabledServicesWithStateDir
      ) enabledServicesWithStateDir;

      additionalStateDirs = [
        "/etc/group"
        "/etc/machine-id"
        "/etc/passwd"
        "/etc/subgid"
        #"/var/backup" # already included in stateDirs as homelab.services.backup.stateDir is set to /var/backup and is included in enabledServicesWithStateDir
      ];

      allStateDirsAndBackupPathsList = stateDirsList ++ additionalStateDirs ++ additionalPathsToBackup;
      allStateDirsAndBackupPaths = lib.concatStringsSep " " allStateDirsAndBackupPathsList;

      # --- Restic Exporter Dynamic Configuration ---
      # One Prometheus exporter per restic backup job; declared here so the backup
      # service owns its monitoring endpoints and Prometheus only aggregates them.
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
            name = "${name}";
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
          environment =
            let
              isS3 = lib.strings.hasPrefix "s3:" exporterConfig.repository;
              refreshInterval = if isS3 then 43200 else 600; # 12h for S3 to reduce the number of S3 API transaction, 10min for others
            in
            {
              LISTEN_ADDRESS = "0.0.0.0";
              LISTEN_PORT = toString exporterConfig.port;
              REFRESH_INTERVAL = toString refreshInterval;
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
    lib.mkIf (cfg.enable && enabledServicesWithStateDir != { }) {
      # Create target directories and enforce the correct permissions and ownership recursively.
      systemd.tmpfiles.rules = lib.lists.optionals cfg.local.enable [
        "d ${cfg.local.targetDir} 0770 ${hl.user} ${hl.group} - -"
        "Z ${cfg.local.targetDir} 0770 ${hl.user} ${hl.group} - -"
        "d ${cfg.local.targetDir}/appdata-local-${config.networking.hostName} 0770 ${hl.user} ${hl.group} - -"
        "Z ${cfg.local.targetDir}/appdata-local-${config.networking.hostName} 0770 ${hl.user} ${hl.group} - -"
      ];
      users.users.restic.createHome = lib.mkForce false;

      users.groups = lib.optionalAttrs (lib.length (lib.attrNames resticBackups) > 0) {
        "restic-exporter" = { };
      };
      users.users."restic-exporter" = lib.mkIf (lib.length (lib.attrNames resticBackups) > 0) {
        isSystemUser = true;
        createHome = lib.mkForce false;
        description = "Runs the restic-exporters";
        group = "restic-exporter";
      };
      environment.systemPackages = lib.optional (
        lib.length (lib.attrNames resticBackups) > 0
      ) pkgs.prometheus-restic-exporter;

      systemd.services = lib.mkMerge [
        {
          # ensure the restic http server is started unprivileged
          restic-rest-server.serviceConfig = lib.attrsets.optionalAttrs cfg.local.enable {
            User = lib.mkForce hl.user;
            Group = lib.mkForce hl.group;
          };
        }
        # the generated exporter services, one per restic backup job
        resticExporterServices
      ];

      # Restic monitoring is appended to the Prometheus configuration via NixOS
      # module merge: the homelab.services.<name>.prometheus.scrapeConfig collector
      # carries exactly one job per service (used for the rest server above), while
      # the exporters are one dynamic job per backup repository.
      services.prometheus = lib.mkIf config.services.prometheus.enable {
        scrapeConfigs = resticScrapeConfigs;
        ruleFiles = [
          (pkgs.writeText "restic.rules.yml" (
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
          ))
        ];
      };

      services.postgresqlBackup = {
        enable = config.services.postgresql.enable;
        databases = config.services.postgresql.ensureDatabases;
        startAt = "*-*-* 03:00:00";
        location = "/var/backup/postgresql";
        compression = "zstd";
        compressionLevel = 12;
      };
      services.mysqlBackup = {
        enable = config.services.mysql.enable;
        databases = config.services.mysql.ensureDatabases;
      };
      services.restic = {
        server = lib.attrsets.optionalAttrs cfg.local.enable {
          enable = true;
          dataDir = cfg.local.targetDir;
          extraFlags = [
            "--no-auth"
          ];
          # Enable rest server Prometheus metrics at /metrics
          prometheus = config.services.prometheus.enable;
        };
        backups =
          lib.attrsets.optionalAttrs cfg.local.enable {
            appdata-local = {
              timerConfig = {
                OnCalendar = "*-*-* 04:00:00"; # or "Mon..Sat *-*-* 04:00:00";
                Persistent = true;
              };
              repository = "rest:http://localhost:${toString cfg.local.listenPort}/appdata-local-${config.networking.hostName}";
              initialize = true;
              passwordFile = cfg.passwordFile;
              inhibitsSleep = true; # Prevents the system from sleeping during backup
              user = "root"; # User to run the backup as, default is root, this ensures the backup has access to all files
              pruneOpts = [
                "--group-by host" # default host,paths would keep snapshots with outdated path sets forever
                "--keep-daily 7"
                "--keep-weekly 4"
                "--keep-monthly 6"
              ];
              exclude =
                [
                ];
              paths = allStateDirsAndBackupPathsList;
              backupPrepareCommand =
                let
                  restic = "${pkgs.restic}/bin/restic -r '${config.services.restic.backups.appdata-local.repository}' -p ${cfg.passwordFile}";
                in
                preBackupCommandsToStopServicesAndStartAfter
                + ''
                  ${restic} stats || ${restic} init
                  ${restic} unlock
                '';
            };
            # restore via: `restic-appdata-local restore latest`
            # to only test the S3 backup, you can run: `restic-appdata-local restore latest --target /tmp/restic-local-test`
          }
          // lib.attrsets.optionalAttrs cfg.s3.enable {
            appdata-s3 =
              let
                backupFolder = "appdata-${config.networking.hostName}";
                tarballPath = "/tmp/appdata-s3-${config.networking.hostName}.tar";
              in
              {
                timerConfig = {
                  OnCalendar = "*-*-* 04:30:00"; # or "Sun *-*-* 04:30:00";
                  Persistent = true;
                };
                environmentFile = cfg.s3.environmentFile;
                repository = "s3:${cfg.s3.url}/${backupFolder}";
                initialize = true;
                passwordFile = cfg.passwordFile;
                inhibitsSleep = true; # Prevents the system from sleeping during backup
                user = "root"; # User to run the backup as, default is root, this ensures the backup has access to all files
                pruneOpts = [
                  "--group-by host" # default host,paths would keep snapshots with outdated path sets forever
                  "--keep-daily 7"
                  "--keep-weekly 4"
                  "--keep-monthly 3"
                ];
                exclude =
                  [
                  ];
                paths = if cfg.s3.useTarball then [ tarballPath ] else allStateDirsAndBackupPathsList;
                backupPrepareCommand =
                  let
                    restic = "${pkgs.restic}/bin/restic -r '${config.services.restic.backups.appdata-s3.repository}' -p ${cfg.passwordFile}";
                  in
                  preBackupCommandsToStopServicesAndStartAfter
                  + ''
                    ${restic} stats || ${restic} init
                    ${lib.optionalString cfg.s3.useTarball ''
                      ${pkgs.gnutar}/bin/tar -cf ${tarballPath} --ignore-failed-read --one-file-system ${allStateDirsAndBackupPaths}
                    ''}
                    ${restic} unlock
                  '';
                backupCleanupCommand = lib.optionalString cfg.s3.useTarball ''
                  rm ${tarballPath}
                '';
              };
            # restore via: `restic-appdata-s3 restore latest`
            # to only test the S3 backup, you can run: `restic-appdata-s3 restore latest --target /tmp/restic-s3-test`
          };

      };
    };
}
