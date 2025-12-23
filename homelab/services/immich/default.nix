{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "immich";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    user = lib.mkOption {
      default = "immich";
      type = lib.types.str;
      description = ''
        The user immich should run as
      '';
    };
    group = lib.mkOption {
      default = "immich";
      type = lib.types.str;
      description = ''
        The group immich should run as
      '';
    };
    mediaDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory where the media files are stored.";
      #This will be backed up via the 'config.homelab.services.backup' service.";
      default = "${config.homelab.mounts.merged}/immich-library";
    };
    # backup.additionalPathsToBackup = import ../../../lib/options/backupAdditionalPathsToBackup.nix {
    #   inherit lib;
    #   additionalPathsToBackup = [ cfg.mediaDir ];
    # };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 2283;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Immich";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted photo and video management solution";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "immich.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    # Ensure media directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0770 ${cfg.user} ${cfg.group} - -"
      "Z ${cfg.mediaDir} 0770 ${cfg.user} ${cfg.group} - -"
    ];

    users.users.immich.extraGroups = [
      "video" # Enabling Hardware Accelerated Video Transcoding
      "render" # Enabling Hardware Accelerated Video Transcoding
      "media" # for access to upload directories
    ];

    environment.systemPackages = [
      pkgs.immich-go
    ];

    services.immich = {
      enable = true;
      host = cfg.listenAddress;
      port = cfg.listenPort;
      user = cfg.user;
      group = cfg.group;
      mediaLocation = "${cfg.mediaDir}";
      database = {
        port = config.services.postgresql.port;
        enableVectors = false;
        enableVectorChord = true;
      };
      accelerationDevices = [ "/dev/dri/renderD128" ];
      # settings = {};
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://${config.services.immich.host}:${toString config.services.immich.port}
      '';
    };
  };
}
