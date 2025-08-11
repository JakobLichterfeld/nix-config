{
  config,
  lib,
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
          "desktop.ini"
        ];
        PAPERLESS_OCR_LANGUAGE = cfg.ocrLanguage;
        PAPERLESS_OCR_USER_ARGS = {
          # see https://ocrmypdf.readthedocs.io/en/latest/api.html#reference for available options
          optimize = 1; # Enables lossless optimizations, such as transcoding images to more efficient formats. Also compress other uncompressed objects in the PDF and enables the more efficient “object streams” within the PDF
          pdfa_image_compression = "lossless"; # use lossless compression for images in the PDF/A output
        };
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
