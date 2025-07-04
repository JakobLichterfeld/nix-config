{
  config,
  pkgs,
  lib,
  ...
}:
let
  advertiseExitNode = lib.hasInfix "server" (lib.toLower config.networking.hostName);
in
{
  environment.systemPackages = [ pkgs.tailscale ];

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

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
