{
  config,
  lib,
  ...
}:
let
  service = "changedetection-io";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/changedetection-io";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "changedetection.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 5000;
    };
    chromePort = lib.mkOption {
      type = lib.types.int;
      description = "A free port on which webDriverSupport or playwrightSupport listen on localhost.";
      default = 4444;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Changedetection.io";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "website change detection";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "changedetection.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkTcpTarget "${service}" "127.0.0.1:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = cfg.listenPort;
      baseURL = "https://${cfg.url}";
      behindProxy = true;
      chromePort = cfg.chromePort; # A free port on which webDriverSupport or playwrightSupport listen on localhost.
      datastorePath = cfg.stateDir;
      # environmentFile = null; # Path to a file containing environment variables, for example for SALTED_PASS
      playwrightSupport = true; # Enable Playwright support for web scraping.
      # webDriverSupport = true; # Enable WebDriver support for web scraping.
    };

    # Playwright can currently leak memory. See https://github.com/dgtlmoon/changedetection.io/wiki/Playwright-content-fetcher#playwright-memory-leak
    # To mitigate this, we can limit the memory usage of the service.
    # This is a workaround until the issue is resolved upstream.
    systemd.services.changedetection-io.serviceConfig =
      lib.mkIf config.services.changedetection-io.playwrightSupport
        {
          MemoryMax = "500M"; # Limit memory usage to 500MB
          Restart = "on-failure";
          RestartSec = "10s";
        };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };
}
