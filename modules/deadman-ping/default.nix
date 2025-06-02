{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.deadman-ping;
in
{
  options.services.deadman-ping = {
    enable = lib.mkEnableOption "Enable periodic external heartbeat ping";

    credentialsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file with the credentials to use for the ping";
      example = lib.literalExpression ''
        pkgs.writeText "deadmanPingEnv" '''
          PING_URL="https://hc-ping.com/your-check-id"
        '''
      '';
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "pinguser";
      description = "User that runs the curl command";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "pinguser";
      description = "Group that runs the curl command";
    };
    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the user defined in `user` automatically as a system user.";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/10";
      description = "systemd OnCalendar expression for the timer";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = lib.mkIf cfg.createUser { };
    users.users.${cfg.user} = lib.mkIf cfg.createUser {
      isSystemUser = true;
      description = "Runs the deadman ping";
      group = cfg.group;
    };

    environment.systemPackages = with pkgs; [
      curl
    ];

    systemd.services.deadman-ping = {
      description = "Send heartbeat ping to external monitoring service";
      after = [ "network-online.target" ] ++ lib.optional config.services.blocky.enable "blocky.service";
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";

        ExecStart = ''
          for i in $(seq 1 5); do
            ${pkgs.curl}/bin/curl -fsS --max-time 10 --connect-timeout 5 -o /dev/null "$PING_URL" && break
            sleep 2
          done
        '';
        TimeoutStartSec = "20s"; # do not block the systemd boot process if the ping fails
        User = cfg.user;
        EnvironmentFile = cfg.credentialsFile;
      };
    };

    systemd.timers.deadman-ping = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };
  };
}
