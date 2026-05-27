{
  config,
  lib,
  pkgs,
  ...
}:

let
  service = "umami";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  recorderCacheDir = "/var/cache/${service}";
  defaultRecordApiEndpoint = "/api/record";
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
    replayScriptName = lib.mkOption {
      type = lib.types.str;
      default = "recorder.js";
      description = "Custom name for the Umami replay recorder script.";
      example = [ "y.js" ];
    };
    recordApiEndpoint = lib.mkOption {
      type = lib.types.str;
      default = defaultRecordApiEndpoint;
      description = "Custom name for the Umami record API endpoint.";
      example = "/api/alternate-record";
    };
    apiHostName = lib.mkOption {
      type = lib.types.str;
      description = "Internal hostname for the Umami API endpoint, primarily used by the Cloudflare Tunnel.";
      default = "umami-api.internal";
    };
    previewOriginToBlock = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Preview origin to block from tracking.";
      example = "https:/xyz.example.com";
    };
    previewRefererToBlock = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Preview referer to block from tracking.";
      example = "*example.com*";
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

    # Patched recorder script to use custom record api endpoint if not using default endpoint name
    systemd.services."umami".wants = lib.mkIf (cfg.recordApiEndpoint != defaultRecordApiEndpoint) [
      "umami-patch-recorder.service"
    ];
    systemd.services."umami-patch-recorder" =
      lib.mkIf (cfg.recordApiEndpoint != defaultRecordApiEndpoint)
        {
          description = "Patch Umami recorder script to use custom record api endpoint";
          after = [ "umami.service" ];
          bindsTo = [ "umami.service" ]; # Stops when umami stops
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            DynamicUser = false;
            User = "caddy";
            Group = "caddy";
            CacheDirectory = "umami";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectClock = true;
            ProtectProc = "noaccess";
            ProcSubset = "pid";
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectControlGroups = true;
            ProtectHostname = true;
            RestrictSUIDSGID = true;
            RestrictRealtime = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            RemoveIPC = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
            CapabilityBoundingSet = "";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
            ];
            ExecStart = pkgs.writeShellScript "patch-recorder" ''
              for i in $(seq 1 10); do
                if ${pkgs.curl}/bin/curl -sf \
                  http://${cfg.listenAddress}:${toString cfg.listenPort}/recorder.js \
                  | ${pkgs.gnused}/bin/sed 's|${defaultRecordApiEndpoint}|${cfg.recordApiEndpoint}|g' \
                  > ${recorderCacheDir}/recorder-patched.js; then
                  chmod 644 ${recorderCacheDir}/recorder-patched.js
                  exit 0
                fi
                sleep 2
              done
              echo "Failed to fetch recorder.js after 10 attempts" >&2
              exit 1
            '';
          };
        };

    # Caddy VHost for the Umami Web UI
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort}
      '';
    };

    # Internal Caddy VHost for the tracking API and recording API, exposed via Cloudflare Tunnel.
    # This serves the tracker and recorder script with a cache header and proxies the collect and record endpoint.
    services.caddy.virtualHosts."http://${cfg.apiHostName}" = {
      extraConfig = ''
        # Health check endpoint
        handle /healthz {
          respond "OK" 200
        }

        # Disallow all crawlers
        handle /robots.txt {
          respond 200 {
            body <<TXT
            User-agent: *
            Disallow: /
            TXT
          }
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
          ${
            lib.optionalString (cfg.previewOriginToBlock != null) ''
              @previewOriginToBlock header Origin ${cfg.previewOriginToBlock}
              respond @previewOriginToBlock 403
            ''
          }
          ${
            lib.optionalString (cfg.previewRefererToBlock != null) ''
              @previewRefererToBlock header Referer ${cfg.previewRefererToBlock}
              respond @previewRefererToBlock 403
            ''
          }
          reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort} {
            header_up Host {http.reverse_proxy.upstream.hostport}
          }
        }

        # Handle the replay recorder script with a custom cache header and if using a custom record API endpoint with a patched record API endpoint
        ${lib.optionalString (cfg.recordApiEndpoint != defaultRecordApiEndpoint) ''
          handle /${cfg.replayScriptName} {
            rewrite * /recorder-patched.js
            header Cache-Control "public, max-age=86400, s-maxage=604800"
            file_server {
              root ${recorderCacheDir}
            }
          }
        ''}

        # Fallback: serve recorder script directly without patching
        ${lib.optionalString (cfg.recordApiEndpoint == defaultRecordApiEndpoint) ''
          handle /${cfg.replayScriptName} {
            rewrite * /recorder.js
            header Cache-Control "public, max-age=86400, s-maxage=604800"
            reverse_proxy http://${cfg.listenAddress}:${toString cfg.listenPort} {
              header_up Host {http.reverse_proxy.upstream.hostport}
            }
          }
        ''}

        # Handle the record endpoint
          handle ${cfg.recordApiEndpoint} {
            ${
              lib.optionalString (cfg.previewOriginToBlock != null) ''
                @previewOriginToBlock header Origin ${cfg.previewOriginToBlock}
                respond @previewOriginToBlock 403
              ''
            }
            ${
              lib.optionalString (cfg.previewRefererToBlock != null) ''
                @previewRefererToBlock header Referer ${cfg.previewRefererToBlock}
                respond @previewRefererToBlock 403
              ''
            }
            ${
              lib.optionalString (cfg.recordApiEndpoint != defaultRecordApiEndpoint) ''
                rewrite * ${defaultRecordApiEndpoint}
              ''
            }
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
