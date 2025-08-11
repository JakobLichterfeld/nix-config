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
    state.enable = lib.mkOption {
      description = "Enable backups for application state folders";
      type = lib.types.bool;
      default = false;
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
        job_name = "restic";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.local.listenPort}" ];
          }
        ];
      };
    };
  };
  config =
    let
      enabledServicesWithStateDir = lib.attrsets.filterAttrs (
        name: value: value ? stateDir && value ? enable && value.enable
      ) hl.services;

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

      allStateDirsList = stateDirsList ++ additionalStateDirs;
      allStateDirs = lib.concatStringsSep " " allStateDirsList;
    in
    lib.mkIf (cfg.enable && enabledServicesWithStateDir != { }) {
      systemd.tmpfiles.rules = lib.lists.optionals cfg.local.enable [
        "d ${cfg.local.targetDir} 0770 ${hl.user} ${hl.group} - -"
        "z ${cfg.local.targetDir} 0770 ${hl.user} ${hl.group} - -"
        "d ${cfg.local.targetDir}/appdata-local-${config.networking.hostName} 0770 ${hl.user} ${hl.group} - -"
      ];
      users.users.restic.createHome = lib.mkForce false;

      # ensure the restic http server is started unprivileged
      systemd.services.restic-rest-server.serviceConfig = lib.attrsets.optionalAttrs cfg.local.enable {
        User = lib.mkForce hl.user;
        Group = lib.mkForce hl.group;
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
          # Enable Prometheus metrics at /metrics
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
                "--keep-daily 7"
                "--keep-weekly 4"
                "--keep-monthly 6"
              ];
              exclude =
                [
                ];
              paths = [
                "/tmp/appdata-local-${config.networking.hostName}.tar"
              ];
              backupPrepareCommand =
                let
                  restic = "${pkgs.restic}/bin/restic -r '${config.services.restic.backups.appdata-local.repository}' -p ${cfg.passwordFile}";
                in
                preBackupCommandsToStopServicesAndStartAfter
                + ''
                  ${restic} stats || ${restic} init
                  ${pkgs.gnutar}/bin/tar -cf /tmp/appdata-local-${config.networking.hostName}.tar --ignore-failed-read ${allStateDirs}
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
                  "--keep-daily 7"
                  "--keep-weekly 4"
                  "--keep-monthly 3"
                ];
                exclude =
                  [
                  ];
                paths = [
                  "/tmp/appdata-s3-${config.networking.hostName}.tar"
                ];
                backupPrepareCommand =
                  let
                    restic = "${pkgs.restic}/bin/restic -r '${config.services.restic.backups.appdata-s3.repository}' -p ${cfg.passwordFile}";
                  in
                  preBackupCommandsToStopServicesAndStartAfter
                  + ''
                    ${restic} stats || ${restic} init
                    ${pkgs.gnutar}/bin/tar -cf /tmp/appdata-s3-${config.networking.hostName}.tar --ignore-failed-read ${allStateDirs}
                    ${restic} unlock
                  '';
              };
            # restore via: `restic-appdata-s3 restore latest`
            # to only test the S3 backup, you can run: `restic-appdata-s3 restore latest --target /tmp/restic-s3-test`
          }
          // lib.attrsets.optionalAttrs (cfg.s3.enable && cfg.paperless.enable) {
            paperless-s3 =
              let
                backupFolder = "paperless-${config.networking.hostName}";
              in
              {
                timerConfig = {
                  OnCalendar = "*-*-* 05:00:00"; # or "Sun *-*-* 05:00:00";
                  Persistent = true;
                };
                environmentFile = cfg.s3.environmentFile;
                repository = "s3:${cfg.s3.url}/${backupFolder}";
                initialize = true;
                passwordFile = cfg.passwordFile;
                inhibitsSleep = true; # Prevents the system from sleeping during backup
                user = "root"; # User to run the backup as, default is root, this ensures the backup has access to all files
                pruneOpts = [
                  "--keep-daily 7"
                  "--keep-weekly 4"
                  # "--keep-monthly 3"
                ];
                exclude =
                  [
                  ];
                paths = [
                  hl.services.paperless.mediaDir
                ];
                backupPrepareCommand =
                  let
                    restic = "${pkgs.restic}/bin/restic -r '${config.services.restic.backups.paperless-s3.repository}' -p ${cfg.passwordFile}";
                  in
                  ''
                    ${restic} stats || ${restic} init
                    ${restic} unlock
                  '';
              };
            # restore via: `restic-paperless-s3 restore latest`
            # to only test the paperless-S3 backup, you can run: `restic-paperless-s3 restore latest --target /tmp/restic-paperless-s3-test`
          };
      };
    };
}
