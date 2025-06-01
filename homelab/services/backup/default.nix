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
    configDir = lib.mkOption {
      description = "Folder with database dump backups (called configDir for compatibility reasons)";
      type = lib.types.str;
      default = "/var/backup";
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
  };
  config =
    let
      enabledServices = (
        lib.attrsets.filterAttrs (
          name: value: value ? configDir && value ? enable && value.enable
        ) hl.services
      );
      stateDirs = lib.strings.concatMapStrings (x: x + " ") (
        lib.lists.forEach (lib.attrsets.mapAttrsToList (name: value: name) enabledServices) (
          x:
          lib.attrsets.attrByPath [
            x
            "configDir"
          ] false enabledServices
        )
      );
      additionalStateDirs = [
        "/etc/group"
        "/etc/machine-id"
        "/etc/passwd"
        "/etc/subgid"
        "/var/backup"
      ];
      allStateDirs = stateDirs + (lib.concatStringsSep " " additionalStateDirs);
    in
    lib.mkIf (cfg.enable && enabledServices != { }) {
      systemd.tmpfiles.rules = lib.lists.optionals cfg.local.enable [
        "d ${cfg.local.targetDir} 0770 ${hl.user} ${hl.group} - -"
        "d ${cfg.local.targetDir}/appdata-local-${config.networking.hostName} 0770 ${hl.user} ${hl.group} - -"
      ];
      users.users.restic.createHome = lib.mkForce false;
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
        };
        backups =
          lib.attrsets.optionalAttrs cfg.local.enable {
            appdata-local = {
              timerConfig = {
                OnCalendar = "*-*-* 04:00:00"; # "Mon..Sat *-*-* 04:00:00";
                Persistent = true;
              };
              repository = "rest:http://localhost:8000/appdata-local-${config.networking.hostName}";
              initialize = true;
              passwordFile = cfg.passwordFile;
              pruneOpts = [
                "--keep-last 5"
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
                ''
                  ${restic} stats || ${restic} init
                  ${pkgs.restic}/bin/restic forget --prune --no-cache --keep-last 5
                  ${pkgs.gnutar}/bin/tar -cf /tmp/appdata-local-${config.networking.hostName}.tar --ignore-failed-read ${allStateDirs}
                  ${restic} unlock
                '';
            };
          }
          // lib.attrsets.optionalAttrs cfg.s3.enable {
            appdata-s3 =
              let
                backupFolder = "appdata-${config.networking.hostName}";
              in
              {
                timerConfig = {
                  OnCalendar = "*-*-* 04:30:00"; # "Sun *-*-* 04:30:00";
                  Persistent = true;
                };
                environmentFile = cfg.s3.environmentFile;
                repository = "s3:${cfg.s3.url}/${backupFolder}";
                initialize = true;
                passwordFile = cfg.passwordFile;
                pruneOpts = [
                  "--keep-last 3"
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
                  ''
                    ${restic} stats || ${restic} init
                    ${pkgs.restic}/bin/restic forget --prune --no-cache --keep-last 3
                    ${pkgs.gnutar}/bin/tar -cf /tmp/appdata-s3-${config.networking.hostName}.tar --ignore-failed-read ${allStateDirs}
                    ${restic} unlock
                  '';
              };
          };
      };
    };
}
