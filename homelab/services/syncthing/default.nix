{
  config,
  lib,
  machinesSensitiveVars,
  ...
}:
let
  service = "syncthing";
  cfg = config.homelab.services.syncthing;
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
      default = "/var/lib/syncthing";
    };
    backup.servicesToManage = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ "${service}.service" ];
      description = ''
        A list of systemd service names to stop before a backup and start afterwards.
        Defaults to the service name itself.
      '';
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.fast}/Syncthing";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8384;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "${service}";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Continuous File Synchronization";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "syncthing.png";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
    prometheus.scrapeConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        job_name = "${service}";
        metrics_path = "/metrics";
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
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {

    # Create directories for Syncthing with the correct permissions and ownership.
    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    # Syncthing ports: 8384 for remote access to GUI
    # 22000 TCP and/or UDP for sync traffic
    # 21027/UDP for discovery
    # source: https://docs.syncthing.net/users/firewall.html
    networking.firewall.allowedTCPPorts = [
      cfg.listenPort
      22000
    ];
    networking.firewall.allowedUDPPorts = [
      22000
      21027
    ];
    services.${service} = {
      enable = true;

      group = homelab.group; # Group to run Syncthing as
      user = homelab.user; # User to run Syncthing as
      dataDir = cfg.dataDir; # Default folder for new synced folders
      configDir = cfg.stateDir; # Folder for Syncthing's settings and keys
      guiAddress = "0.0.0.0:${toString cfg.listenPort}"; # Listen on all interfaces
      overrideFolders = false;
      overrideDevices = false;
    };

    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };
}
