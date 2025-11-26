{
  config,
  lib,
  pkgs,
  ...
}:

let
  service = "matomo";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    enableConsole = lib.mkEnableOption {
      description = "Enable the matomo-console command-line tool.";
      default = false;
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/matomo";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "matomo.${homelab.baseDomain}";
    };
    apiHostName = lib.mkOption {
      type = lib.types.str;
      description = "Internal hostname for the Matomo API endpoint, primarily used by the Cloudflare Tunnel.";
      default = "matomo-api.internal";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Matomo";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Web & app analytics";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "matomo.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Professional";
    };
    cloudflared = {
      fqdn = lib.mkOption {
        type = lib.types.str;
        description = "The fully qualified domain name (FQDN) for the Matomo tracking API endpoint.";
        example = "stats.your-domain.com";
      };
      tunnelId = lib.mkOption {
        type = lib.types.str;
        description = "The ID of the Cloudflare Tunnel.";
        example = "00000000-0000-0000-0000-000000000000";
      };
      credentialsFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to the Cloudflare Tunnel credentials file.";
        example = lib.literalExpression ''
          pkgs.writeText "cloudflare-credentials.json" '''
          {"AccountTag":"secret"."TunnelSecret":"secret","TunnelID":"secret","Endpoint":""}
          '''
        '';
      };
    };
    blackbox.targets = import ../../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
          (blackbox.mkHttpTarget "${service}" "${cfg.cloudflared.fqdn}" "external")
        ];
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.matomo = {
        enable = true;
        hostname = cfg.url;
        webServerUser = "caddy";
        periodicArchiveProcessing = true; # Enable periodic archive processing, which generates aggregated reports from the visits.
      };

      # enable mySQL database, as the service does not configure it by itself
      # https://matomo.org/faq/how-to-install/faq_55/
      # PostgreSQL is not "yet" supported, see https://github.com/matomo-org/matomo/issues/500
      # connection is done via sockets
      services.mysql = {
        enable = true;
        package = pkgs.mariadb;
        settings = {
          mysqld = {
            max_allowed_packet = "128M";
          };
        };

        ensureDatabases = [ "matomo" ];
        ensureUsers = [
          {
            name = "matomo";
            ensurePermissions."matomo.*" = "ALL PRIVILEGES";
          }
        ];
      };

      services.caddy.virtualHosts."${cfg.url}" = {
        useACMEHost = homelab.baseDomain;
        # extraConfig similar to NGINX from module: https://raw.githubusercontent.com/NixOS/nixpkgs/refs/heads/master/nixos/modules/services/web-apps/matomo.nix
        extraConfig = ''
          root * ${config.services.matomo.package}/share

          # 1. Security rules: These are primary handlers.
          # If a request matches, Caddy responds 403 and stops.

          # Block access to sensitive directories and file types
          @blockdirs path_regexp blockdirs ^/(config|core|lang|misc|tmp)/
          respond @blockdirs "Forbidden" 403

          @blockfiles path_regexp blockfiles \.(bat|git|ini|sh|txt|tpl|xml|md)$
          respond @blockfiles "Forbidden" 403

          @unwanted_php {
            path_regexp \.php$
            not path /index.php /matomo.php /piwik.php
          }
          respond @unwanted_php "Forbidden" 403

          # 2. PHP handler for specific entrypoints
          @php path /index.php /matomo.php /piwik.php
          php_fastcgi @php unix/${config.services.phpfpm.pools.matomo.socket}

          # 3. Static file handler for everything else
          # This will serve existing files like CSS/JS.
          # If a file doesn't exist (e.g., /vanity-url), it will produce a 404 error.
          file_server

          # 4. Error handler: Catch 404s and rewrite to index.php for pretty URLs
          # This replaces `try_files`.
          handle_errors {
            rewrite * /index.php
            php_fastcgi unix/${config.services.phpfpm.pools.matomo.socket}
          }

          # robots.txt rule
          @robots path /robots.txt
          respond @robots "User-agent: *\nDisallow: /\n" 200

          # Cache JavaScript files
          @matomojs path /matomo.js /piwik.js
          header @matomojs Cache-Control "public, max-age=2592000"
        '';
      };

      # only API endpoint for cloudflared access
      services.caddy.virtualHosts."http://${cfg.apiHostName}" = {
        extraConfig = ''
          # Set the web root to the Matomo package directory so Caddy can find the files
          root * ${config.services.matomo.package}/share

          # Unset the X-Forwarded-Host header. Matomo would otherwise prioritize
          # this header, see it's not a trusted host, and issue a redirect.
          header -X-Forwarded-Host

          # Rewrite all paths to matomo.php to only expose the API endpoint for the cloudflared tunnel
          rewrite * /matomo.php

          # FastCGI settings
          # We explicitly set the HTTP_HOST for PHP to the main, trusted URL.
          # This prevents Matomo from redirecting to its primary hostname.
          php_fastcgi unix/${config.services.phpfpm.pools.matomo.socket} {
            env HTTP_HOST ${cfg.url}
            env SERVER_NAME ${cfg.url}
          }
        '';
      };

      # Cloudflare tunnel for API endpoint
      services.cloudflared = {
        enable = true;
        tunnels = {
          "${cfg.cloudflared.tunnelId}" = {
            credentialsFile = cfg.cloudflared.credentialsFile;
            default = "http_status:404"; # All requests that do not comply with one of the following rules will be blocked.
            ingress = {
              "${cfg.cloudflared.fqdn}" = {
                service = "http://localhost";
                originRequest = {
                  httpHostHeader = "${cfg.apiHostName}";
                };
              };
            };
          };
        };
      };
    })
    (lib.mkIf cfg.enableConsole {
      # idiomatic way to access matomo console
      environment.systemPackages = with pkgs; [
        (callPackage ./console.nix {
          matomoPackage = config.services.matomo.package;
          matomoUser = "matomo";
          matomoStateDir = cfg.stateDir;
        })
      ];
    })
  ];
}
