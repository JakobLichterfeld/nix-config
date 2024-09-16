{ config, vars, machinesSensitiveVars, ... }:
{
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53; # Port for incoming DNS Queries.
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
      ];
      # For initially solving DoH/DoT Requests when no system Resolver is available.
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = [ "1.1.1.1" "1.0.0.1" ];
      };
      #Enable Blocking of certian domains.
      blocking = {
        blackLists = {
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
          ];
          adult = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
            "https://blocklistproject.github.io/Lists/porn.txt"
          ];
        };
        whiteLists = {
          ads = [
            pkgs.writeTextFile
            {
              name = "whitelist.txt";
              text = builtins.readFile ./whitelist.txt;
            }
          ];
            };

          blockType = zeroIp;

          #Configure what block categories are used
          clientGroupsBlock = {
            default = [ "ads" "adult" ];
          };

          caching = {
            minTime = "5m";
            maxTime = "30m";
            prefetching = true;
          };
        };
        clientLookup.upstream = machinesSensitiveVars.MainServer.defaultGateway;
      };
    };
  }
