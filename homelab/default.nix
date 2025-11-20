{
  lib,
  config,
  machinesSensitiveVars,
  ...
}:
let
  cfg = config.homelab;
in
{
  options.homelab = {
    enable = lib.mkEnableOption "The homelab services and configuration variables";
    mounts.slower = lib.mkOption {
      default = "/mnt/mergerfs_slower";
      type = lib.types.path;
      description = ''
        Path to the 'slower' tier mount
      '';
    };
    mounts.fast = lib.mkOption {
      default = "/mnt/cache";
      type = lib.types.path;
      description = ''
        Path to the 'fast' tier mount
      '';
    };
    mounts.config = lib.mkOption {
      default = "/persist/opt/services";
      type = lib.types.path;
      description = ''
        Path to the service configuration files
      '';
    };
    mounts.merged = lib.mkOption {
      default = "/mnt/user";
      type = lib.types.path;
      description = ''
        Path to the merged tier mount
      '';
    };
    user = lib.mkOption {
      default = "share";
      type = lib.types.str;
      description = ''
        User to run the homelab services as
      '';
      #apply = old: builtins.toString config.users.users."${old}".uid;
    };
    group = lib.mkOption {
      default = "share";
      type = lib.types.str;
      description = ''
        Group to run the homelab services as
      '';
      #apply = old: builtins.toString config.users.groups."${old}".gid;
    };
    timeZone = lib.mkOption {
      default = "Europe/Berlin";
      type = lib.types.str;
      description = ''
        Time zone to be used for the homelab services
      '';
    };
    baseDomain = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = ''
        Base domain name to be used to access the homelab services via Caddy reverse proxy
      '';
    };
    baseDomainFallback = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = ''
        Fallback domain name to be used to access the homelab services via Caddy reverse proxy
      '';
    };
    # cloudflare.dnsCredentialsFile = lib.mkOption {
    #   type = lib.types.path;
    # };
  };
  imports = [
    ./services
    ./samba
  ];
  config = lib.mkIf cfg.enable {
    users = {
      groups.${cfg.group} = {
        gid = 993;
      };
      users.${cfg.user} = {
        uid = 994;
        isSystemUser = true;
        group = cfg.group;
      };
    };

    # Create config directory and enforce the correct permissions and ownership recursively.
    systemd.tmpfiles.rules = lib.mkBefore [
      "d /persist 0755 root root - -"
      "d /persist/opt 0755 root root - -"
      "d ${cfg.mounts.config} 0775 ${cfg.user} ${cfg.group} - -"
      "Z ${cfg.mounts.config} 0775 ${cfg.user} ${cfg.group} - -"
    ];
  };
}
