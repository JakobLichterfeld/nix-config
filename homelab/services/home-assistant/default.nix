{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  service = "home-assistant";
  homelab = config.homelab;
  cfg = config.homelab.services.home-assistant;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable Home Assistant";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory containing the persistent state data to back up";
      default = "/var/lib/hass";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8123;
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Home Assistant";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Home automation platform";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Smart Home";
    };

    blackbox.targets = import ../../../lib/options/blackboxTargets.nix {
      inherit lib;
      defaultTargets =
        let
          blackbox = import ../../../lib/blackbox.nix { inherit lib; };
        in
        [
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.postgresql.enable;
        message = "Home Assistant requires PostgreSQL in this config. Please set services.postgresql.enable = true;";
      }
    ];

    services.home-assistant = {
      enable = true;
      package = pkgsUnstable.home-assistant;
      extraPackages = ps: with ps; [ psycopg2 ]; # recorder postgresql support

      extraComponents = [
        # Components required to complete the onboarding
        "analytics"
        "google_translate" # Google Translate text-to-speech
        "met" # default weather provider: Meteorologisk institutt (Met.no)
        "radio_browser"
        "shopping_list"
        "isal" # Intelligent Storage Acceleration, recommended for fast zlib compression, see https://www.home-assistant.io/integrations/isal

        "apple_tv" # Apple TV
        "devolo_home_control" # Devolo Home Control
        "devolo_home_network" # Devolo
        "dlna_dmr" # DLNA Digital Media Renderer
        "fritz" # AVM FRITZ!Box Tools, presence detection via TR-064
        "fritzbox" # AVM FRITZ!SmartHome
        "home_connect" # Home Connect
        "nmap_tracker" # Nmap Tracker
        "upnp" # Universal Plug and Play to collect data from routers
        "vacuum" # home cleaning robots

      ];

      config =
        {
          homeassistant.time_zone = homelab.timeZone;

          # Use PostgreSQL as the database backend for the recorder component
          recorder.db_url = "postgresql://@/hass"; # connect via UNIX socket using peer auth; no password needed if user matches

          http = {
            server_port = cfg.listenPort;
            server_host = "127.0.0.1";
            trusted_proxies = [ "127.0.0.1" ];
            use_x_forwarded_for = true;
          };

          # Includes dependencies for a basic setup
          # https://www.home-assistant.io/integrations/default_config/
          default_config = { };

          # YAML configuration files
          "automation nixos" = [
            # YAML automations go here
          ];
          "scene nixos" = [
            # YAML scenes go here
          ];
          "script nixos" = [
            # YAML scripts go here
          ];
        }
        # Include YAML files created from the UI, if these are available
        // lib.optionalAttrs (builtins.pathExists "${cfg.stateDir}/automations.yaml") {
          "automation ui" = "!include automations.yaml";
        }
        // lib.optionalAttrs (builtins.pathExists "${cfg.stateDir}/scenes.yaml") {
          "scene ui" = "!include scenes.yaml";
        }
        // lib.optionalAttrs (builtins.pathExists "${cfg.stateDir}/scripts.yaml") {
          "script ui" = "!include scripts.yaml";
        };
    };

    # use the PostgreSQL database for Home Assistant for improved performance and reliability
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "hass" ];
      ensureUsers = [
        {
          name = "hass";
          ensureDBOwnership = true;
        }
      ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };
}
