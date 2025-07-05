{
  config,
  pkgs,
  lib,
  ...
}:
let
  advertiseExitNode = lib.hasInfix "server" (lib.toLower config.networking.hostName);
  possibleIfaces = [
    "enp1s0"
    "enp2s0"
    "eth0"
    "eno1"
    "eth0"
    "eth1"
  ];
  existingIfaces = builtins.filter (iface: config.networking.interfaces ? ${iface}) possibleIfaces;
  mainInterface = if existingIfaces != [ ] then builtins.head existingIfaces else "eth0";
in
{
  environment.systemPackages =
    [ pkgs.tailscale ]
    ++ lib.optionals advertiseExitNode [
      pkgs.ethtool
    ]
    ++ lib.optionals (advertiseExitNode && config.networking.useNetworkd) [
      pkgs.networkd-dispatcher
    ];

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  # optimize UDP throughput, see https://wiki.nixos.org/wiki/Tailscale#Optimize_the_performance_of_subnet_routers_and_exit_nodes and https://tailscale.com/kb/1320/performance-best-practices#ethtool-configuration
  services.networkd-dispatcher = lib.mkIf (advertiseExitNode && config.networking.useNetworkd) {
    enable = true;
    rules."50-tailscale" = {
      onState = [ "routable" ];
      script = ''
        for iface in ${builtins.toString possibleIfaces}; do
          if [[ -e /sys/class/net/$iface ]]; then
            ${lib.getExe pkgs.ethtool} -K $iface rx-udp-gro-forwarding on rx-gro-list off
          fi
        done
      '';
    };
  };
  systemd.services.ethtool-tuning = lib.mkIf (advertiseExitNode && !config.networking.useNetworkd) {
    description = "Apply ethtool tuning to interfaces to optimize UDP throughput for Tailscale exit nodes";
    after = [ "network-online.target" ];
    before = [ "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ethtool-tune" ''
        for iface in ${builtins.toString possibleIfaces}; do
          if [[ -e /sys/class/net/$iface ]]; then
            ${lib.getExe pkgs.ethtool} -K $iface rx-udp-gro-forwarding on rx-gro-list off
          fi
        done
      '';
    };
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscaleAuthKey.path;

    useRoutingFeatures = if advertiseExitNode then "both" else "client";
    permitCertUid = if config.services.caddy.enable then "caddy" else null; # Allow the Caddy user(and service) to edit certs, see https://wiki.nixos.org/wiki/Tailscale#Configuring_TLS

    extraUpFlags = lib.optionals (advertiseExitNode) [
      "--advertise-exit-node"
      "--exit-node-allow-lan-access"
      "--reset"
    ];
  };
}
