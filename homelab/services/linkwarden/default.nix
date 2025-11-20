{
  config,
  lib,
  pkgsUnstable,
  ...
}:
let
  service = "linkwarden";
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
      default = "/var/lib/linkwarden";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 3010;
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. NEXTAUTH_SECRET and POSTGRES_PASSWORD";
      type = with lib.types; nullOr path;
      default = config.age.secrets.linkwardenEnv.path;
      example = lib.literalExpression ''
        pkgs.writeText "linkwarden-secret-environment" '''
          NEXTAUTH_SECRET=<secret>
          POSTGRES_PASSWORD=<pass>
        '''
      '';
    };
    database = {
      port = lib.mkOption {
        type = lib.types.int;
        default = config.services.postgresql.settings.port;
        description = "Port of the PostgreSQL database";
      };
    };
    enableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow user registration in Linkwarden";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Linkwarden";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Bookmark manager with web scraping support";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "linkwarden.png";
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
      package = pkgsUnstable.linkwarden;
      host = cfg.listenAddress;
      port = cfg.listenPort;
      database.port = cfg.database.port;
      storageLocation = cfg.stateDir;
      enableRegistration = cfg.enableRegistration;
      # environment = { }; # https://docs.linkwarden.app/self-hosting/environment-variables
      environmentFile = lib.mkIf (cfg.secretEnvironmentFile != null) cfg.secretEnvironmentFile; # Path to a file containing environment variables, for example for NEXTAUTH_SECRET=<secret>,   POSTGRES_PASSWORD=<pass>
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
      '';
    };
  };
}
