{
  config,
  lib,
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
      config = "/persist/opt/services";
      slower = "/mnt/mergerfs_slower";
      fast = "/mnt/cache";
      merged = "/mnt/user";
    };
    samba = {
      enable = true;
      sambaUsers = [
        {
          username = "jakob";
          passwordFile = config.age.secrets.sambaPassword.path;
        }
        {
          username = "christine";
          passwordFile = config.age.secrets.sambaPasswordChristine.path;
        }
      ];
      shares = {
        TimeMachine = {
          path = "${hl.mounts.fast}/TimeMachine";
          filesystemOwner = "jakob";
          filesystemGroup = "users";
          validUsers = "@users";
          extraOptions = {
            "fruit:time machine" = "yes";
          };
        };
        # Operating Company
        ${machinesSensitiveVars.OperatingCompany.name} = {
          path = "${hl.mounts.merged}/${machinesSensitiveVars.OperatingCompany.name}";
          filesystemOwner = "${lib.toLower machinesSensitiveVars.OperatingCompany.name}";
          filesystemGroup = "${lib.toLower machinesSensitiveVars.OperatingCompany.name}";
          validUsers = "@${lib.toLower machinesSensitiveVars.OperatingCompany.name}";
        };
        # Holding Company Jakob
        ${machinesSensitiveVars.HoldingCompanyJakob.name} = {
          path = "${hl.mounts.merged}/${machinesSensitiveVars.HoldingCompanyJakob.name}";
          filesystemOwner = "${lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name}";
          filesystemGroup = "${lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name}";
          validUsers = "@${lib.toLower machinesSensitiveVars.HoldingCompanyJakob.name}";
        };
        # Holding Company Christine
        ${machinesSensitiveVars.HoldingCompanyChristine.name} = {
          path = "${hl.mounts.merged}/${machinesSensitiveVars.HoldingCompanyChristine.name}";
          filesystemOwner = "${lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name}";
          filesystemGroup = "${lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name}";
          validUsers = "@${lib.toLower machinesSensitiveVars.HoldingCompanyChristine.name}";
        };
        # Personal Shares
        Jakob = {
          path = "${hl.mounts.merged}/Jakob";
          filesystemOwner = "jakob";
          filesystemGroup = "jakob";
          validUsers = "@jakob";
        };
        Christine = {
          path = "${hl.mounts.merged}/Christine";
          filesystemOwner = "christine";
          filesystemGroup = "christine";
          validUsers = "@christine";
        };
        # Paperless Import Share
        "Paperless-Import" = {
          path = config.homelab.services.paperless.consumptionDir;
          managePermissions = false; # Let the paperless module handle permissions
          validUsers = "@users"; # Allow all users to access the import share
          extraOptions = {
            "guest ok" = "yes";
            "writable" = "yes";
          };
        };
      };
    };
    services = {
      enable = true;

      backup = {
        enable = true;
        passwordFile = config.age.secrets.resticPassword.path;
        s3.enable = true;
        s3.url = machinesSensitiveVars.S3Storage.url;
        s3.environmentFile = config.age.secrets.s3StorageEnv.path;
        local.enable = true;
      };

      blocky.enable = true;

      changedetection-io.enable = true;

      home-assistant.enable = true;

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
            name = "Localsend Web";
            description = "Service to seamless share clipboard, files, notifications";
            icon = "https://play-lh.googleusercontent.com/t2xwoWAJPoIHZlYiw82J31fZl40kj962j5DVHohn-Pgn7ZiuoXCl-2_NMyMERa7cCFw=w240-h480-rw";
            href = "https://web.localsend.org";
            siteMonitor = "https://web.localsend.org";
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

      linkwarden.enable = true;

      ntfy-sh.enable = true;

      owntracks-recorder.enable = true;

      # paperless.enable = true; # TODO(JakobLichterfeld): re-enable once the error "attribute 'nltkData' missing" is resolved

      prometheus = {
        enable = true;
        fritzboxExporter.enable = true;
        telegramCredentialsFile = config.age.secrets.telegramCredentials.path;
        telegramChatId = machinesSensitiveVars.MainServer.telegramChatId;
        blackbox.hostSpecificTargets =
          let
            blackbox = import ../../../../lib/blackbox.nix { inherit lib; };
          in
          [
            (blackbox.mkHttpTargetCritical "networking-router"
              "http://${machinesSensitiveVars.MainServer.defaultGateway}"
              "network"
            )
          ]
          ++ lib.optional config.services.tailscale.enable (
            blackbox.mkIcmpTargetCritical "tailscale_self" machinesSensitiveVars.MainServer.ipAddressTailscale
              "self"
          )

          ++ lib.optional config.services.zerotierone.enable (
            blackbox.mkIcmpTargetCritical "zerotier_self" machinesSensitiveVars.MainServer.ipAddressZerotier
              "self"
          );
      };

      stirling-pdf.enable = true;

      syncthing.enable = true;

      teslamate.enable = true;
      teslamate-abrp.enable = true;
      teslamate-telegram-bot.enable = true;

      uptime-kuma.enable = true;

      vaultwarden.enable = true;
    };
  };
}
