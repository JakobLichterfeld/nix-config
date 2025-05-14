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
  configDir = "${vars.serviceConfigRoot}/syncthing";
  directories = [
  configDir
];
in
{
  options.homelab.services.syncthing = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };
  config = lib.mkIf cfg.enable {

    # Create directories for Syncthing with the correct permissions and ownership.
    systemd.tmpfiles.rules = map (x: "d ${x} 0775 ${homelab.user} ${homelab.group} - -") directories;

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
      dataDir = "${vars.mainArray}/sync"; # Default folder for new synced folders
      configDir = configDir; # Folder for Syncthing's settings and keys
      guiAddress = "0.0.0.0:8384"; # Listen on all interfaces
      overrideFolders = false;
      overrideDevices = false;
    };

    services.caddy.virtualHosts."${homelab.baseDomain}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8384
      '';
    };
  };
}
