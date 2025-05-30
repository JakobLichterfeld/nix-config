{
  config,
  pkgs,
  lib,
  vars,
  machinesSensitiveVars,
  ...
}:
let
  service = "blocky";
  cfg = config.homelab.services.blocky;
  homelab = config.homelab;
in
{
  options.homelab.services.blocky = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    prometheus.scrapeConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        job_name = "${service}";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [ "localhost:4443" ];
          }
        ];
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;

      settings = {
        ports = {
          dns = 53; # Port for incoming DNS Queries.
          https = "localhost:4443,127.0.0.1:4443,[::1]:4443"; # Port(s) and optional bind ip address(es) to serve HTTPS used for prometheus metrics, pprof, REST API, DoH...
        };
        upstreams.groups.default = [
          "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
        ];
        # For initially solving DoH/DoT Requests when no system Resolver is available.
        bootstrapDns = {
          upstream = "https://one.one.one.one/dns-query";
          ips = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        };
        #Enable Blocking of certain domains.
        blocking = {
          denylists = {
            ads = [
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
              "https://adaway.org/hosts.txt"
              "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt"
              "https://raw.githubusercontent.com/vincentkenny01/spotblock/master/spotify"
              "https://v.firebog.net/hosts/AdguardDNS.txt"
              "https://v.firebog.net/hosts/Easylist.txt"
              "https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt"
              "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
              "https://v.firebog.net/hosts/RPiList-Malware.txt"
              "https://v.firebog.net/hosts/RPiList-Phishing.txt"
              "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
              "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
              "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
              "https://v.firebog.net/hosts/Easyprivacy.txt"
              "https://v.firebog.net/hosts/Prigent-Ads.txt"
              (pkgs.writeTextFile {
                name = "denylists.txt";
                text = builtins.readFile ./denylists.txt;
              }).outPath
            ];
            adult = [
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
              "https://blocklistproject.github.io/Lists/porn.txt"
            ];
          };
          allowlists = {
            ads = [
              (pkgs.writeTextFile {
                name = "allowlists.txt";
                text = builtins.readFile ./allowlists.txt;
              }).outPath
            ];
          };

          blockType = "zeroIp";

          #Configure what block categories are used
          clientGroupsBlock = {
            default = [
              "ads"
              "adult"
            ];
          };
        };

        caching = {
          minTime = "5m";
          maxTime = "30m";
          prefetching = true;
        };

        prometheus = {
          # Enable Prometheus metrics endpoint
          enable = config.services.prometheus.enable;
          # Path for the metrics endpoint, default is /metrics
          path = "/metrics";
        };

        clientLookup.upstream = machinesSensitiveVars.MainServer.defaultGateway;
      };

    };
  };
}
