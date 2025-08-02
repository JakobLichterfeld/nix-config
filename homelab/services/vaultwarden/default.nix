{
  config,
  lib,
  pkgsUnstable,
  ...
}:
let
  service = "vaultwarden";
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
      default = "/var/lib/bitwarden_rs";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8222;
    };
    secretEnvironmentFile = lib.mkOption {
      description = "File with secret environment variables, e.g. ADMIN_TOKEN and SMTP_PASSWORD";
      type = with lib.types; nullOr path;
      default = config.age.secrets.vaultwardenEnv.path;
      example = lib.literalExpression ''
        pkgs.writeText "owntracks-recorder-secret-environment" '''
          ADMIN_TOKEN=$argon2id$v=19$m=65540,t=3,p=4$...
          SMTP_PASSWORD=<your-smtp-password>

        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Vaultwarden";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Password manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden.svg";
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
    assertions = [
      {
        assertion = config.services.postgresql.enable;
        message = "Vaultwarden requires PostgreSQL in this config. Please set services.postgresql.enable = true;";
      }
    ];

    services.${service} = {
      enable = true;
      package = pkgsUnstable.vaultwarden;
      dbBackend = "postgresql";
      config =
        {
          DOMAIN = "https://${cfg.url}";
          SIGNUPS_ALLOWED = false;
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = cfg.listenPort;
          EXTENDED_LOGGING = true;
          LOG_LEVEL = "warn";
          IP_HEADER = "X-Forwarded-For";
          DATABASE_URL = "postgresql://vaultwarden@/vaultwarden"; # Connect via UNIX socket using peer auth; no password needed if user matches
        }
        // (
          if config.email.enable then
            {
              SMTP_HOST = "${config.email.smtpServer}";
              SMTP_PORT = "${toString config.email.smtpPort}";
              SMTP_SECURITY = "starttls";
              SMTP_FROM = "${config.email.fromAddress}";
              SMTP_USERNAME = "${config.email.smtpUsername}";
            }
          else
            { }
        );
      environmentFile = cfg.secretEnvironmentFile; # Vaultwarden secret environment variables, so ADMIN_TOKEN=$argon2id$v=19$m=65540,t=3,p=4$..., SMTP_PASSWORD= and DATABASE_URL=postgresql://vaultwarden:secretpassword@localhost/vaultwarden or DATABASE_URL=postgresql://vaultwarden@/vaultwarden if using different auth method
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "vaultwarden" ];
      ensureUsers = [
        {
          name = "vaultwarden";
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
