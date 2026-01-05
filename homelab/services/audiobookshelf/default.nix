{ config, lib, ... }:
let
  service = "audiobookshelf";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    user = lib.mkOption {
      default = "audiobookshelf";
      type = lib.types.str;
      description = ''
        User account under which Audiobookshelf runs.
      '';
    };
    group = lib.mkOption {
      default = "audiobookshelf";
      type = lib.types.str;
      description = ''
        Group under which Audiobookshelf runs.
      '';
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/${service}";
    };
    audiobooksDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory where the audiobook files are stored.";
      #This will be backed up via the 'config.homelab.services.backup' service.", if added to backup.additionalPathsToBackup
      default = "${config.homelab.mounts.merged}/media/audiobooks";
    };
    podcastsDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory where the podcast files are stored.";
      #This will be backed up via the 'config.homelab.services.backup' service.", if added to backup.additionalPathsToBackup
      default = "${config.homelab.mounts.merged}/media/podcasts";
    };
    # backup.additionalPathsToBackup = import ../../../lib/options/backupAdditionalPathsToBackup.nix {
    #   inherit lib;
    #   additionalPathsToBackup = [ cfg.audiobooksDir cfg.podcastsDir];
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
      default = 8003;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Audiobookshelf";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Audiobook and Podcast Media Server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "audiobookshelf.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${
            service
          }" "http://${cfg.listenAddress}:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {

    # Ensure media directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.audiobooksDir} 0770 ${cfg.user} ${cfg.group} - -"
      "Z ${cfg.audiobooksDir} 0770 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.podcastsDir} 0770 ${cfg.user} ${cfg.group} - -"
      "Z ${cfg.podcastsDir} 0770 ${cfg.user} ${cfg.group} - -"
    ];

    users.users.${cfg.user}.extraGroups = [
      "media" # for access to media directory
    ];

    services.audiobookshelf = {
      enable = true;
      host = cfg.listenAddress;
      port = cfg.listenPort;
      user = cfg.user;
      group = cfg.group;
      dataDir = service; # path to Audiobookshelf config and metadata inside of /var/lib -> /var/lib/audiobookshelf
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://${config.services.${service}.host}:${toString config.services.${service}.port}
      '';
    };
  };

}
