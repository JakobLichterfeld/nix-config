{
  config,
  lib,
  pkgs,
  ...
}:
# Caddy is baseline infrastructure for the homelab: every service publishes its
# virtual host through it, so it is always active together with
# homelab.services.enable and deliberately has no enable option of its own --
# a toggle nobody may switch off would only fake variability. Cross-cutting
# concerns stay in ../default.nix: ACME certificates (also consumed by blocky),
# the firewall openings and the caddy user with the shared ACME group.
{
  config = lib.mkIf config.homelab.services.enable {
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

    # Caddy's monitoring (scrape job and alert rules) is appended to the
    # Prometheus configuration via NixOS module merge: the service owning the
    # endpoint declares itself, Prometheus only aggregates. Without a
    # homelab.services entry Caddy cannot use the
    # homelab.services.<name>.prometheus.scrapeConfig collector.
    services.prometheus = lib.mkIf config.services.prometheus.enable {
      scrapeConfigs = [
        {
          job_name = "caddy";
          static_configs = [
            {
              targets = [ "localhost:2019" ]; # Caddy admin endpoint exposes /metrics
            }
          ];
        }
      ];
      ruleFiles = [
        (pkgs.writeText "caddy.rules.yml" (
          builtins.toJSON {
            groups = [
              {
                name = "caddy";
                rules = [
                  {
                    # All Caddy reverse proxies are down
                    # from https://samber.github.io/awesome-prometheus-alerts/rules
                    alert = "CaddyReverseProxyDown";
                    expr = ''count(caddy_reverse_proxy_upstreams_healthy) by (upstream) == 0'';
                    for = "0m";
                    labels = {
                      severity = "critical";
                    };
                    annotations = {
                      summary = "Caddy Reverse Proxy Down (instance {{ $labels.instance }})";
                      description = "All Caddy reverse proxies are down\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                    };
                  }
                  {
                    # Caddy service 4xx error rate is above 5%
                    # from https://samber.github.io/awesome-prometheus-alerts/rules
                    alert = "CaddyHighHttp4xxErrorRateService";
                    expr = ''sum(rate(caddy_http_request_duration_seconds_count{code=~"4.."}[3m])) by (instance) / sum(rate(caddy_http_request_duration_seconds_count[3m])) by (instance) * 100 > 5'';
                    for = "1m";
                    labels = {
                      severity = "critical";
                    };
                    annotations = {
                      summary = "Caddy high HTTP 4xx error rate service (instance {{ $labels.instance }})";
                      description = "Caddy service 4xx error rate is above 5%\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                    };
                  }
                  {
                    # Caddy service 5xx error rate is above 5%
                    # from https://samber.github.io/awesome-prometheus-alerts/rules
                    alert = "CaddyHighHttp5xxErrorRateService";
                    expr = ''sum(rate(caddy_http_request_duration_seconds_count{code=~"5.."}[3m])) by (instance) / sum(rate(caddy_http_request_duration_seconds_count[3m])) by (instance) * 100 > 5'';
                    for = "1m";
                    labels = {
                      severity = "critical";
                    };
                    annotations = {
                      summary = "Caddy high HTTP 5xx error rate service (instance {{ $labels.instance }})";
                      description = "Caddy service 5xx error rate is above 5%\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
                    };
                  }
                ];
              }
            ];
          }
        ))
      ];
    };
  };
}
