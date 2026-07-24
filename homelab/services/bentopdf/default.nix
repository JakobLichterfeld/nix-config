{ config, lib, ... }:
let
  service = "bentopdf";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    # NOTE: bentopdf is a purely client-side toolkit served as static files by
    # Caddy. There is no server process, no listen port and no persistent state,
    # hence no stateDir/backup target.
    url = lib.mkOption {
      type = lib.types.str;
      default = "pdf-bento.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "BentoPDF";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Privacy-first, client-side PDF toolkit";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "bentopdf.svg";
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
          # No internal target: static files are served directly by Caddy on
          # 443 (SNI), there is no local HTTP listener to probe.
          (blackbox.mkHttpTarget "${service}" "${cfg.url}" "external")
        ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.bentopdf = {
      enable = true;
      domain = cfg.url;
      caddy = {
        enable = true;
        # Reuse the shared wildcard ACME certificate for baseDomain instead of
        # letting Caddy provision its own; the module's file_server/SPA config
        # is merged in via types.lines and stays untouched.
        virtualHost.useACMEHost = homelab.baseDomain;
      };
    };
  };
}
