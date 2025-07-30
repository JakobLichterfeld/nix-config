{
  config,
  lib,
  pkgs,
  machinesSensitiveVars,
  inputs,
  ...
}:
let
  acmeSharedGroup = "acme-shared";
in
{
  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";
  };

  config = lib.mkIf config.homelab.services.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    users.groups.${acmeSharedGroup} = { };
    users.users.caddy = {
      isSystemUser = true;
      description = "Runs Caddy service";
      group = "caddy";
      extraGroups = [ acmeSharedGroup ]; # Add to shared group for ACME certificate access.
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "${machinesSensitiveVars.MainServer.letsencryptEmail}";
      defaults.postRun = ''
        ${lib.optionalString config.services.blocky.enable "systemctl restart blocky.service"}
      '';
      certs = lib.mkMerge [
        {
          "${config.homelab.baseDomain}" = {
            reloadServices = [ "caddy.service" ];
            domain = "${config.homelab.baseDomain}";
            extraDomainNames = [ "*.${config.homelab.baseDomain}" ];
            dnsProvider = "${machinesSensitiveVars.MainServer.dnschallengeProvider}";
            dnsResolver = "1.1.1.1:53";
            dnsPropagationCheck = true;
            group = acmeSharedGroup;
            environmentFile = config.age.secrets.dnsApiCredentials.path;
          };
        }
        (lib.optionalAttrs (config.homelab.baseDomainFallback != null) {
          "${config.homelab.baseDomainFallback}" = {
            reloadServices = [ "caddy.service" ];
            domain = "${config.homelab.baseDomainFallback}";
            extraDomainNames = [ "*.${config.homelab.baseDomainFallback}" ];
            dnsProvider = "${machinesSensitiveVars.MainServer.dnschallengeProvider}";
            dnsResolver = "1.1.1.1:53";
            dnsPropagationCheck = true;
            group = acmeSharedGroup;
            environmentFile = config.age.secrets.dnsApiCredentials.path;
          };
        })
      ];
    };
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = {
        "http://${config.homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${config.homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };

        "http://${config.homelab.baseDomainFallback}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${config.homelab.baseDomainFallback}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };

      };
    };
    nixpkgs.config.permittedInsecurePackages = [
      "dotnet-sdk-6.0.428"
      "aspnetcore-runtime-6.0.36"
    ];
    virtualisation.podman = {
      dockerCompat = true;
      autoPrune.enable = true;
      extraPackages = [ pkgs.zfs ];
      defaultNetwork.settings = {
        dns_enabled = !config.homelab.services.blocky.enable; # only enable podman's internal DNS if blocky is not enabled
      };
    };
    virtualisation.oci-containers = {
      backend = "podman";
    };

    networking.firewall.interfaces."podman+".allowedUDPPorts =
      lib.lists.optionals config.virtualisation.podman.enable
        [ 53 ];
  };

  imports = [
    ./backup
    ./blocky
    ./home-assistant
    ./homepage
    ./ntfy-sh
    ./owntracks-recorder
    ./prometheus
    ./stirling-pdf
    ./syncthing
    ./teslamate
    ./teslamate-abrp
    ./teslamate-telegram-bot
    ./uptime-kuma
    ./vaultwarden
  ];
}
