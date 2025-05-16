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
        extraServices = [
          {
            category = "Other Devices";
            name = "FritzBox";
            description = "DSL/Cable Modem WebUI";
            href = "http://${machinesSensitiveVars.MainServer.defaultGateway}";
            siteMonitor = "http://${machinesSensitiveVars.MainServer.defaultGateway}";
            icon = "avm-fritzbox.png";
          }
          {
            category = "Other Devices";
            name = "Devolo Powerline Adapter Wohnzimmer";
            description = "Powerline Adapter im Wohnzimmer";
            icon = "mdi-lan";
            href = "http://${machinesSensitiveVars.Powerline.ipAddressLivingRoom}";
            siteMonitor = "http://${machinesSensitiveVars.Powerline.ipAddressLivingRoom}";
          }
          {
            category = "Other Devices";
            name = "Devolo Powerline Adapter Schlafzimmer";
            description = "Powerline Adapter im Schlafzimmer";
            icon = "mdi-lan";
            href = "http://${machinesSensitiveVars.Powerline.ipAddressBedroom}";
            siteMonitor = "http://${machinesSensitiveVars.Powerline.ipAddressBedroom}";
          }
          {
            category = "Mobile";
            name = "Join";
            description = "Service to seamless share clipboard, files, notifications";
            icon = "https://play-lh.googleusercontent.com/hXPaRP8HSOYVgaMHCYx7mYOqb8hhcpVxFFz0_n61v543ZzxCME98chPwFlElv9M3D7U=w240-h480-rw";
            href = "https://joinjoaomgcd.appspot.com";
            siteMonitor = "https://joinjoaomgcd.appspot.com";
          }
          {
            category = "Mobile";
            name = "WhatsApp Web";
            description = "Quickly send and receive WhatsApp messages right from your browser";
            icon = "whatsapp";
            href = "https://web.whatsapp.com";
            siteMonitor = "https://web.whatsapp.com";
          }
          {
            category = "Mobile";
            name = "AirDroid ${machinesSensitiveVars.MobileMainDev.name}";
            description = "Dateiübertragung und -verwaltung";
            icon = "https://cdn.icon-icons.com/icons2/278/PNG/512/AirDroid_30195.png";
            href = "https://${machinesSensitiveVars.MobileMainDev.ipAddress}:${toString machinesSensitiveVars.MobileMainDev.airDroidPort}";
            siteMonitor = "https://${machinesSensitiveVars.MobileMainDev.ipAddress}:${toString machinesSensitiveVars.MobileMainDev.airDroidPort}";
          }
          {
            category = "Mobile";
            name = "AirDroid ${machinesSensitiveVars.MobileMainDevTablet.name}";
            description = "Dateiübertragung und -verwaltung";
            icon = "https://cdn.icon-icons.com/icons2/278/PNG/512/AirDroid_30195.png";
            href = "https://${machinesSensitiveVars.MobileMainDevTablet.ipAddress}:${toString machinesSensitiveVars.MobileMainDevTablet.airDroidPort}";
            siteMonitor = "https://${machinesSensitiveVars.MobileMainDevTablet.ipAddress}:${toString machinesSensitiveVars.MobileMainDevTablet.airDroidPort}";
          }
          {
            category = "External Services";
            name = "DuckDNS";
            description = "Dynamic DNS for fixed public IP";
            icon = "duckdns";
            href = "https://www.duckdns.org/domains";
            siteMonitor = "https://www.duckdns.org/domains";
          }
          {
            category = "External Services";
            name = "Tailscale";
            description = "Secure networks between devices";
            icon = "tailscale";
            href = "https://login.tailscale.com/admin/machines";
            siteMonitor = "https://login.tailscale.com";
          }
          {
            category = "External Services";
            name = "Zerotier";
            description = "Secure networks between devices";
            icon = "si-zerotier";
            href = "https://my.zerotier.com";
            siteMonitor = "https://my.zerotier.com";
          }
          {
            category = "External Services";
            name = "HealthChecks";
            description = "Cron Job Monitorings";
            icon = "https://healthchecks.io/static/img/logo.svg";
            href = "https://healthchecks.io/projects/fad147f3-3d1c-4a26-8a22-48dfd032b9f5/checks/";
            siteMonitor = "https://healthchecks.io";
          }
        ];
      };

      syncthing.enable = true;

      teslamate.enable = true;
    };
  };
}
