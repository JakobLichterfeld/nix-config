{
  config,
  pkgs,
  lib,
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
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 4001;
      description = "HTTP Port on which Blocky will provide Prometheus metrics, pprof, REST API, DoH...";
    };
    prometheus.scrapeConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        job_name = "${service}";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.listenPort}" ];
          }
        ];
      };
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${
            service
          }" "http://127.0.0.1:${toString cfg.listenPort}/metrics" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}/metrics" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    services.${service} = {
      enable = true;

      settings = {
        ports = {
          dns = "0.0.0.0:53"; # Port for incoming DNS Queries.
          http = "localhost:${toString cfg.listenPort}"; # Port(s) and optional bind ip address(es) to serve HTTP used for prometheus metrics, pprof, REST API, DoH...
        };
        upstreams = {
          strategy = "strict"; # Use strict upstreams, meaning that all queries will be sent to the first upstream in the list.  If the first upstream does not respond, the second is asked, and so on.
          groups.default = [
            "https://unfiltered.joindns4.eu/dns-query" # DNS4EU DNS-over-HTTPS (DoH)
            "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
          ];
        };
        # For initially solving DoH/DoT Requests when no system Resolver is available.
        bootstrapDns = {
          upstream = "https://unfiltered.joindns4.eu/dns-query";
          ips = [
            "86.54.11.100" # DNS4EU unfiltered
            "86.54.11.200" # DNS4EU unfiltered
            "1.1.1.1" # Cloudflare DNS
            "1.0.0.1" # Cloudflare DNS
          ];
        };
        #Enable Blocking of certain domains.
        blocking = {
          denylists = {
            ads = [
              # Blocks Ads, Affiliate, Tracking, Metrics, Telemetry, Phishing, Malware, Scam, Fake, Cryptojacking and other "Crap".
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt"
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
              "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareDomains.txt"
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
            bypassPrevention = [
              # Prevent methods to bypass your DNS, blocks encrypted DNS, VPN, TOR, Proxies.
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/doh-vpn-proxy-bypass.txt"
            ];
            threatIntelligenceFeeds = [
              # Blocks domains known to spread malware, launch phishing attacks and host command-and-control servers.
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.txt"
            ];
            adult = [
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/nsfw.txt"
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
              "https://github.com/hagezi/dns-blocklists/blob/main/wildcard/whitelist-referral-onlydomains.txt" # This list unblocks affiliate & tracking referral links that appear in mails, search results etc.
            ];
          };

          blockType = "zeroIp";

          #Configure what block categories are used
          clientGroupsBlock = {
            default = [
              "ads"
              "bypassPrevention"
              "threatIntelligenceFeeds"
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

    # Enable reverse proxy for Prometheus metrics scraping
    services.caddy.virtualHosts."${cfg.url}" = lib.mkIf config.services.prometheus.enable {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy /metrics http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };
}
