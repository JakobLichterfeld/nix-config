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
  cfg = config.homelab.services;
in
{
  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";

    dnsApiCredentialsFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the secrets for the DNS provider API used for ACME DNS challenges.";
      default = config.age.secrets.dnsApiCredentials.path;
    };
    dnsApiCredentialsFallbackFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the secrets for the DNS provider API used for ACME DNS challenges.";
      default = config.age.secrets.dnsApiCredentialsFallback.path;
    };
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
      defaults = {
        email = "${machinesSensitiveVars.dns.letsencryptEmail}";
        reloadServices = [
          "caddy.service"
        ] ++ lib.optional config.services.blocky.enable "blocky.service";

      };
      certs = lib.mkMerge [
        {
          "${config.homelab.baseDomain}" = {
            domain = "${config.homelab.baseDomain}";
            extraDomainNames = [ "*.${config.homelab.baseDomain}" ];
            dnsProvider = "${machinesSensitiveVars.dns.challengeProvider}";
            dnsPropagationCheck = true;
            dnsResolver = "1.1.1.1:53";
            group = acmeSharedGroup;
            environmentFile = cfg.dnsApiCredentialsFile;
          };
        }
        (lib.optionalAttrs (config.homelab.baseDomainFallback != null) {
          "${config.homelab.baseDomainFallback}" = {
            domain = "${config.homelab.baseDomainFallback}";
            extraDomainNames = [ "*.${config.homelab.baseDomainFallback}" ];
            dnsProvider = "${machinesSensitiveVars.dns.challengeProviderFallback}";
            dnsPropagationCheck = true;
            dnsResolver = "1.1.1.1:53";
            environmentFile = cfg.dnsApiCredentialsFallbackFile;
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
        dns_enabled = lib.mkForce (!config.homelab.services.blocky.enable); # only enable podman's internal DNS if blocky is not enabled
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
    ./audiobookshelf
    ./backup
    ./blocky
    ./changedetection-io
    ./home-assistant
    ./homepage
    ./immich
    ./languagetool
    ./linkwarden
    ./ntfy-sh
    ./owntracks-recorder
    ./pairdrop
    ./paperless-ngx
    ./professional/matomo
    ./professional/umami
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
