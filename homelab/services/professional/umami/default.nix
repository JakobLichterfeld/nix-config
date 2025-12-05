{
  config,
  lib,
  ...
}:

let
  service = "umami";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "umami.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 3030;
    };
    appSecretFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      description = "Path to a file containing the application secret for Umami.";
    };
    trackerScriptName = lib.mkOption {
      type = lib.types.str;
      default = "script.js";
      description = "Custom name for the Umami tracker script.";
      example = [ "x.js" ];
    };
    collectApiEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "/api/send";
      description = "Custom name for the Umami collect API endpoint.";
      example = "/api/alternate-send";
    };
    apiHostName = lib.mkOption {
      type = lib.types.str;
      description = "Internal hostname for the Umami API endpoint, primarily used by the Cloudflare Tunnel.";
      default = "umami-api.internal";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Umami";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Website analytics";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "umami.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Professional";
    };
    cloudflared = {
      fqdn = lib.mkOption {
        type = lib.types.str;
        description = "The fully qualified domain name (FQDN) for the Umami tracking API endpoint.";
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

  config = lib.mkIf cfg.enable {
    services.umami = {
      enable = true;
      createPostgresqlDatabase = true;
      settings = {
        HOSTNAME = cfg.listenAddress;
        PORT = cfg.listenPort;
        APP_SECRET_FILE = cfg.appSecretFile;
        DISABLE_UPDATES = true;
        DISABLE_TELEMETRY = true;
        CLIENT_IP_HEADER = "CF-Connecting-IP";
        COLLECT_API_ENDPOINT = cfg.collectApiEndpoint;
        TRACKER_SCRIPT_NAME = [ cfg.trackerScriptName ];
      };
    };

    # Caddy VHost for the Umami Web UI
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort}
      '';
    };

    # Internal Caddy VHost for the tracking API, exposed via Cloudflare Tunnel.
    # This serves the tracker script with a cache header and proxies the collect endpoint.
    services.caddy.virtualHosts."http://${cfg.apiHostName}" = {
      extraConfig = ''
        # Health check endpoint
        handle /healthz {
          respond "OK" 200
        }

        # Disallow all crawlers
        handle /robots.txt {
          respond "User-agent: *\nDisallow: /\n" 200
        }

        # Handle the tracker script with a custom cache header.
        handle /${cfg.trackerScriptName} {
          header Cache-Control "public, max-age=86400, s-maxage=604800"
          reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort} {
            header_up Host {http.reverse_proxy.upstream.hostport}
          }
        }

        # Handle the collection endpoint.
        handle ${cfg.collectApiEndpoint} {
          reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort} {
            header_up Host {http.reverse_proxy.upstream.hostport}
          }
        }

        # Catch-all for all other requests
        handle {
          respond 404
        }
      '';
    };

    # Cloudflare tunnel for the tracking endpoint
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
  };
}
