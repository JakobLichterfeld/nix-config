{ config, vars, ... }:
{
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

  services = {
    syncthing = {
      enable = true;
      user = "sync"; # User to run Syncthing as
      dataDir = "/mnt/data1/sync"; # Default folder for new synced folders
      configDir = "/mnt/data1/sync/.config/syncthing"; # Folder for Syncthing's settings and keys
      guiAddress = "0.0.0.0:8384"; # Listen on all interfaces
    };
  };
}
