{ config, lib, ... }:
let
  service = "ntfy-sh";
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
      default = "/var/lib/ntfy-sh";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8080;
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = service;
      description = "User to run the service as";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = service;
      description = "Group to run the service as";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Ntfy";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Push notifications to your devices";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "ntfy";
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
          (blackbox.mkHttpTarget "${service}" "http://127.0.0.1:${toString cfg.listenPort}" "internal")
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      settings = {
        base-url = "https://${cfg.url}";
        listen-http = ":${toString cfg.listenPort}";
        behind-proxy = true;
      };
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };

}
