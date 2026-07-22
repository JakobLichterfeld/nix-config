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
        metrics # HTTP metrics are opt-in since Caddy 2.9; exposed via the admin endpoint at localhost:2019/metrics
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
    # append the Caddy scrape job to the Prometheus scrape configuration via NixOS module merge;
    # Caddy is baseline infrastructure without its own homelab.services entry
    services.prometheus.scrapeConfigs = lib.mkIf config.services.prometheus.enable [
      {
        job_name = "caddy";
        static_configs = [
          {
            targets = [ "localhost:2019" ]; # Caddy admin endpoint exposes /metrics
          }
        ];
      }
    ];
    services.logrotate = {
      enable = true;

      settings.caddy = {
        files = "${config.services.caddy.logDir}/*.log"; # rotate all Caddy log files in the configured log directory

        frequency = "weekly"; # run log rotation once per week
        rotate = 12; # keep the last 12 rotated log files --> 12 weeks

        compress = true; # compress rotated logs to save disk space
        delaycompress = true; # delay compression until the next rotation cycle

        missingok = true; # do not fail if log files are missing
        notifempty = true; # skip rotation for empty log files

        sharedscripts = true; # run postrotate only once even if multiple files match

        create = "0640 ${config.services.caddy.user} ${config.services.caddy.group}"; # create new log files with correct permissions

        postrotate = ''
          systemctl reload caddy
        ''; # reload Caddy so it reopens the log files
      };

    };
    # nixpkgs.config.permittedInsecurePackages = [
    # ];
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
    ./loki
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
