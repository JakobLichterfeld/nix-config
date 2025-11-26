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
          (blackbox.mkHttpTarget "${service}" "${cfg.cloudflared.fqdn}/healthz" "external")
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

      # Update Matomo Config
      systemd.services.matomo-setup-update.postStart = ''
        config_file="/var/lib/matomo/config/config.ini.php"

        # Add trusted_hosts entry for the Cloudflare FQDN
        trusted_host_line='trusted_hosts[] = "${cfg.cloudflared.fqdn}"'
        if ! grep -qF -- "$trusted_host_line" "$config_file"; then
          # Use `echo` and `r /dev/stdin` for robust insertion of the variable's value
          echo "$trusted_host_line" | sed -i '/\[General\]/r /dev/stdin' "$config_file"
        fi

        # Ensure HTTP_X_FORWARDED_FOR is present
        proxy_xff_line='proxy_client_headers[] = "HTTP_X_FORWARDED_FOR"'
        if ! grep -qF -- "$proxy_xff_line" "$config_file"; then
          echo "$proxy_xff_line" | sed -i '/\[General\]/r /dev/stdin' "$config_file"
        fi

        # Ensure HTTP_CF_CONNECTING_IP is present and comes after HTTP_X_FORWARDED_FOR
        proxy_cf_line='proxy_client_headers[] = "HTTP_CF_CONNECTING_IP"'
        if ! grep -qF -- "$proxy_cf_line" "$config_file"; then
          # Check if XFF is already there (or was just added)
          if grep -qF -- "$proxy_xff_line" "$config_file"; then
            # Use grep -n to get the line number and sed with the line number to append.
            # This is more robust than using a variable with regex metacharacters in a sed address.
            line_num=$(grep -nF -- "$proxy_xff_line" "$config_file" | cut -d: -f1)
            if [ -n "$line_num" ]; then
              echo "$proxy_cf_line" | sed -i "$line_num r /dev/stdin" "$config_file"
            else
              # Fallback just in case grep fails unexpectedly after succeeding before
              echo "$proxy_cf_line" | sed -i '/\[General\]/r /dev/stdin' "$config_file"
            fi
          else
            # Fallback: if XFF isn't there, add CF after [General].
            echo "$proxy_cf_line" | sed -i '/\[General\]/r /dev/stdin' "$config_file"
          fi
        fi
      '';

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
          # Health check endpoint that bypasses Matomo
          @healthz path /healthz
          respond @healthz "OK" 200

          # Disallow all crawlers
          @robots path /robots.txt
          respond @robots "User-agent: *\nDisallow: /\n" 200

          # Set the web root for all other requests to the Matomo package directory so Caddy can find the files
          root * ${config.services.matomo.package}/share

          # Rewrite all other paths to matomo.php to only expose the API endpoint for the cloudflared tunnel
          @not_healthz not path /healthz /robots.txt
          rewrite @not_healthz /matomo.php

          # FastCGI settings for the rewritten paths
          php_fastcgi unix/${config.services.phpfpm.pools.matomo.socket}
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
