{
  config,
  pkgs,
  lib,
  machinesSensitiveVars,
  inputs,
  ...
}:
let
  service = "blocky";
  cfg = config.homelab.services.blocky;
  homelab = config.homelab;
  globalAllowlist =
    (pkgs.writeTextFile {
      name = "allowlists.txt";
      text = builtins.readFile ./allowlists.txt;
    }).outPath;
in
{
  options.homelab.services.blocky = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
      description = "URL for the Blocky service, used for Prometheus metrics scraping.";
    };
    doh.url = lib.mkOption {
      type = lib.types.str;
      default = "dns.${homelab.baseDomain}";
      description = "URL for the Blocky service, used for DNS-over-HTTPS (DoH) requests.";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 4001;
      description = "HTTP Port on which Blocky will provide Prometheus metrics, pprof, REST API, DoH...";
    };
    dot.listenPort = lib.mkOption {
      type = lib.types.int;
      default = 853;
      description = "Port on which Blocky will listen for DNS-over-TLS (DoT) requests.";
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
    networking.firewall.allowedTCPPorts = [
      53
      cfg.dot.listenPort
    ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # If you want to debug via dig, use `nix-shell -p dnsutils`

    # used for TLS for DoT
    users.groups.${service} = { };
    users.users.${service} = {
      isSystemUser = true;
      description = "Runs ${service} service";
      group = service;
      extraGroups = [ "acme-shared" ]; # Add to shared group for ACME certificate access.
    };

    services.${service} = {
      enable = true;

      settings = {
        ports = {
          dns = "0.0.0.0:53"; # Port for incoming DNS Queries.
          http = "127.0.0.1:${toString cfg.listenPort}"; # Port(s) and optional bind ip address(es) to serve HTTP used for prometheus metrics, pprof, REST API, DNS-over-HTTPS (DoH) requests via: https://host:port/dns-query
          tls = "0.0.0.0:${toString cfg.dot.listenPort}"; # Port(s) and optional bind ip address(es) to serve DNS-over-TLS (DoT) requests via: host:port
        };
        # Path to the ACME certificate and key files for DNS-over-TLS (DoT) and DNS-over-HTTPS (DoH).
        # These files are automatically managed by the ACME service.
        certFile = config.security.acme.certs.${homelab.baseDomain}.directory + "/fullchain.pem"; # Path to the certificate file for DoT.
        keyFile = config.security.acme.certs.${homelab.baseDomain}.directory + "/key.pem"; # Path to the private key file for DoT.

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
              "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
              "https://adaway.org/hosts.txt"
              "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt"
              (pkgs.writeTextFile {
                name = "spotblock-cleaned";
                text = builtins.replaceStrings [ "\\" ] [ " " ] (builtins.readFile "${inputs.spotblock}/spotify");
              }).outPath
              "https://v.firebog.net/hosts/AdguardDNS.txt"
              "https://v.firebog.net/hosts/Easylist.txt"
              "https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt"
              "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
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
            ];
          };
          allowlists = {
            ads = [
              globalAllowlist
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/refs/heads/main/wildcard/whitelist-referral-onlydomains.txt" # This list unblocks affiliate & tracking referral links that appear in mails, search results etc.
            ];
            bypassPrevention = [ globalAllowlist ];
            threatIntelligenceFeeds = [ globalAllowlist ];
            adult = [ globalAllowlist ];
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

        log = {
          level = "error";
          privacy = true;
        };

        prometheus = {
          # Enable Prometheus metrics endpoint
          enable = config.services.prometheus.enable;
          # Path for the metrics endpoint, default is /metrics
          path = "/metrics";
        };

        clientLookup = {
          upstream = machinesSensitiveVars.MainServer.defaultGateway;
          singleNameOrder = [
            2
            1
          ];
        };
      };

    };

    # Blocky has no sd_notify support (checked against v0.29.0 and main), so
    # with Type=simple its start job completes on fork, while the blocking
    # loading strategy keeps every listener closed until all lists are loaded.
    # Units ordered after blocky would therefore start before name resolution
    # works. Hold the start job until blocky answers on its HTTP
    # API: DNS and HTTP listeners open together in server.Start(), after the
    # blocking resolver is built.
    #
    # Fail open: the probe orders other units, it is not blocky's health check.
    # A broken or timed-out probe must never take the resolver down, so the
    # "-" prefix ignores its exit status and the probe's own deadline stays
    # below TimeoutStartSec. Dependents then start unordered and fail loudly
    # on their own, exactly as they did before this probe existed.
    #
    # curl, not dig: ExecStartPost runs inside the unit's sandbox, and the
    # module's SystemCallFilter (~@aio) kills dig with SIGSYS in libuv's
    # io_uring setup. curl only needs socket/connect/poll/read/write, all in
    # @system-service.
    #
    # Dependents never name this unit. nss-lookup.target is systemd's
    # synchronisation point for name resolution; the nixpkgs module already
    # registers blocky as a provider (Wants= and Before= the target), so with
    # the probe above the target only becomes active once blocky answers, and
    # units ordered After=nss-lookup.target wait exactly as long as needed.
    #
    # That covers boot only. nss-lookup.target carries RefuseManualStart, so
    # switch-to-configuration never restarts it, and a Wants= on an already
    # active target queues no job. After a switch, a restart or a crash of
    # blocky the target would stay active without a job and order nothing.
    # PropagatesStopTo= takes the target down together with blocky in all
    # three cases (explicit stop, restart, unexpected exit); the next start of
    # blocky then queues a real start job for the target, ordered after the
    # probe, and dependents wait on it again. Requirement-free: stopping or
    # starting the target never stops or starts blocky.
    systemd.services.blocky.unitConfig.PropagatesStopTo = "nss-lookup.target";
    systemd.services.blocky.serviceConfig = {
      ExecStartPost = "-${pkgs.writeShellScript "blocky-wait-ready" ''
        deadline=300 # seconds, must stay below TimeoutStartSec
        while (( SECONDS < deadline )); do
          if ${lib.getExe pkgs.curl} --silent --fail --max-time 2 --output /dev/null \
              http://127.0.0.1:${toString cfg.listenPort}/api/blocking/status; then
            exit 0
          fi
          sleep 1
        done
        echo "blocky did not answer on 127.0.0.1:${toString cfg.listenPort} within $deadline s, dependents start unordered" >&2
        exit 1
      ''}";
      TimeoutStartSec = "6min";
    };

    # Blocky serves DoT and DoH from this certificate and has no ExecReload,
    # so a renewal restarts it (try-reload-or-restart falls back to restart).
    # Registered on the certificate blocky reads, not as an ACME default: the
    # fallback certificate is not used here and must not restart the resolver.
    security.acme.certs.${homelab.baseDomain}.reloadServices = [ "blocky.service" ];

    # Enable reverse proxy DoH
    services.caddy.virtualHosts."${cfg.doh.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy /dns-query http://127.0.0.1:${toString cfg.listenPort}
      '';
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
