{
  config,
  lib,
  vars,
  machinesSensitiveVars,
  ...
}:
let
  hl = config.homelab;
in
{
  homelab = {
    enable = true;
    baseDomain = machinesSensitiveVars.MainServer.baseDomain;
    baseDomainFallback = machinesSensitiveVars.MainServer.baseDomainFallback;

    timeZone = "Europe/Berlin";
    mounts = {
      config = vars.serviceConfigRoot;
      slow = vars.slowerArray;
      fast = vars.cacheArray;
      merged = vars.mainArray;
    };
    samba = {
      enable = true;
      passwordFile = config.age.secrets.sambaPassword.path;
      shares = {
        Backups = {
          path = "${hl.mounts.merged}/Backups";
        };
        Documents = {
          path = "${hl.mounts.fast}/Documents";
        };
        Media = {
          path = "${hl.mounts.merged}/Media";
        };
        Music = {
          path = "${hl.mounts.fast}/Media/Music";
        };
        Misc = {
          path = "${hl.mounts.merged}/Misc";
        };
        TimeMachine = {
          path = "${hl.mounts.fast}/TimeMachine";
          "fruit:time machine" = "yes";
        };
      };
    };
    services = {
      enable = true;

      blocky.enable = true;

      homepage = {
        enable = true;
        misc = [
          {
            FritzBox = {
              href = "http://${machinesSensitiveVars.MainServer.defaultGateway}";
              siteMonitor = "http://${machinesSensitiveVars.MainServer.defaultGateway}";
              description = "DSL/Cable Modem WebUI";
              icon = "avm-fritzbox.png";
            };
          }
        ];
      };
    };
  };
}
