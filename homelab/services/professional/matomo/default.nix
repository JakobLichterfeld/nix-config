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
      systemd.services.matomo-setup-update.postStart =
        (pkgs.writeShellScript "matomo-config-update" ''
          set -e
          CONFIG_FILE="/var/lib/matomo/config/config.ini.php"


          # Exit if the config file doesn't exist.
          if [ ! -f "$CONFIG_FILE" ]; then
            echo "Matomo config file not found at $CONFIG_FILE, skipping update."
            exit 0
          fi

          # Create a temporary file containing a cleaned version of the config,
          # without the lines we intend to manage. This is safer than in-place sed.
          CLEAN_CONFIG=$(mktemp)

          # Ensure temp files are cleaned up on exit
          trap 'rm -f "$CLEAN_CONFIG" "$FINAL_CONFIG"' EXIT

          # Create a clean version of the config without our managed lines.
          # We use `grep -vE` to match keys regardless of their value, making the script robust.
          grep -vE '^\s*host\s*=' "$CONFIG_FILE" \
          | grep -vE '^\s*username\s*=' \
          | grep -vE '^\s*dbname\s*=' \
          | grep -vE '^\s*tables_prefix\s*=' \
          | grep -vE '^\s*schema\s*=' \
          | grep -vE '^\s*charset\s*=' \
          | grep -vE '^\s*collation\s*=' \
          \
          | grep -vE '^\s*proxy_client_headers\[\]\s*=' \
          | grep -vE '^\s*trusted_hosts\[\]\s*=' \
          > "$CLEAN_CONFIG"

          FINAL_CONFIG=$(mktemp)

          # Use awk to build the correct final config
          ${pkgs.gawk}/bin/awk -v fqdn="${cfg.cloudflared.fqdn}" -v url="${cfg.url}" \
                -v db_host="localhost" \
                -v db_username="matomo" \
                -v db_name="matomo" \
                -v db_prefix="matomo_" \
                -v db_schema="Mariadb" \
                -v db_charset="utf8mb4" \
                -v db_collation="utf8mb4_general_ci" '
            { print } # Print the current line from the clean config

            # --- Insert lines for [database] section ---
            /^\[database\]/ {
              print "host = \"" db_host "\""
              print "username = \"" db_username "\""
              print "dbname = \"" db_name "\""
              print "tables_prefix = \"" db_prefix "\""
              print "schema = \"" db_schema "\""
              print "charset = \"" db_charset "\""
              print "collation = \"" db_collation "\""
            }

            # --- Insert lines for [General] section ---
            /^\[General\]/ {
              print "trusted_hosts[] = \"" fqdn "\""
              print "trusted_hosts[] = \"" url "\""
              print "proxy_client_headers[] = \"HTTP_CF_CONNECTING_IP\""
              print "proxy_client_headers[] = \"HTTP_X_FORWARDED_FOR\""
            }
          ' "$CLEAN_CONFIG" > "$FINAL_CONFIG"

          # Atomically replace the original config file with the corrected version
          mv "$FINAL_CONFIG" "$CONFIG_FILE"

          # Correct the ownership and permissions to match what Matomo expects
          chown ${config.services.phpfpm.pools.matomo.user}:${config.services.phpfpm.pools.matomo.group} "$CONFIG_FILE"
          chmod 660 "$CONFIG_FILE"
        '').outPath;

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
