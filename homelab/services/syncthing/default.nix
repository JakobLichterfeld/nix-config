{
  config,
  lib,
  vars,
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
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${vars.serviceConfigRoot}/${service}";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${vars.mainArray}/sync";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
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
  };
  config = lib.mkIf cfg.enable {

    # Create directories for Syncthing with the correct permissions and ownership.
    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    # Syncthing ports: 8384 for remote access to GUI
    # 22000 TCP and/or UDP for sync traffic
    # 21027/UDP for discovery
    # source: https://docs.syncthing.net/users/firewall.html
    networking.firewall.allowedTCPPorts = [
      8384
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
      configDir = cfg.configDir; # Folder for Syncthing's settings and keys
      guiAddress = "0.0.0.0:8384"; # Listen on all interfaces
      overrideFolders = false;
      overrideDevices = false;
    };

    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8384
      '';
    };
  };
}
