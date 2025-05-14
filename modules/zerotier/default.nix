{
  config,
  pkgs,
  lib,
  machinesSensitiveVars,
  ...
}:
{
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      machinesSensitiveVars.MainServer.zerotierNetworkId
    ];
  };

  networking.firewall.trustedInterfaces = [ machinesSensitiveVars.MainServer.zerotierNetworkAdapter ];
  networking.firewall.allowedUDPPorts = [ config.services.zerotierone.port ];
}
