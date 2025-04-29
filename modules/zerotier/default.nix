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
}
