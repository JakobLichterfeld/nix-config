{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.dns-updater;
in
{
  options.services.dns-updater = {
    enable = lib.mkEnableOption "Enable periodical update of dynamic DNS entries.";

    updateUrl = lib.mkOption {
      type = lib.types.str;
      description = "The URL to use for dynamic DNS updates.";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain to update.";
    };
    ipv4Address = lib.mkOption {
      type = lib.types.str;
      description = "The IPv4 address to set for the domain.";
      default = "";
    };
    ipv6Address = lib.mkOption {
      type = lib.types.str;
      description = "The IPv6 address to set for the domain.";
      default = "";
    };
    ddnsTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the DDNS token file.";
      default = config.age.secrets.ddnsToken.path;
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = "systemd OnUnitActiveSec expression for the timer";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.ipv4Address != "" || cfg.ipv6Address != "";
        message = "At least one of ipv4Address or ipv6Address must be set.";
      }
    ];

    environment.systemPackages = with pkgs; [
      curl
    ];

    systemd.services.dns-updater = {
      description = "Periodically update dynamic DNS entries with current IP addresses";
      after =
        [
          "network-online.target"
        ]
        ++ lib.optional config.services.tailscale.enable "tailscaled.service"
        ++ lib.optional config.services.blocky.enable "blocky.service";
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 10;
        LoadCredential = [ "DDNS_TOKEN:${cfg.ddnsTokenFile}" ];
        PrivateTmp = true;
        # Hardening
        CapabilityBoundingSet = lib.mkDefault [ "" ];
        DeviceAllow = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = lib.mkDefault true;
        ProtectClock = lib.mkDefault true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = lib.mkDefault "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ]; # only allow IPv4 and IPv6
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
      script = ''
        set -eu

        UPDATE_URL="${cfg.updateUrl}"
        DOMAIN="${cfg.domain}"
        IPV4_ADDRESS="${cfg.ipv4Address}"
        IPV6_ADDRESS="${cfg.ipv6Address}"
        DDNS_TOKEN=$(cat $CREDENTIALS_DIRECTORY/DDNS_TOKEN)

        IPV4_PARAM=""
        if [ -n "$IPV4_ADDRESS" ]; then
          IPV4_PARAM="&myipv4=$IPV4_ADDRESS"
        fi

        IPV6_PARAM=""
        if [ -n "$IPV6_ADDRESS" ]; then
          IPV6_PARAM="&myipv6=$IPV6_ADDRESS"
        fi

        ${pkgs.curl}/bin/curl -sS "$UPDATE_URL/?hostname=$DOMAIN''${IPV4_PARAM}''${IPV6_PARAM}" \
          --header "Authorization: Token $DDNS_TOKEN"
      '';
    };

    systemd.timers.dns-updater = {
      description = "Run dynamic DNS update periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1m";
        OnActiveSec = "30s"; # run shortly after rebuilds
        OnUnitActiveSec = cfg.interval;
        Unit = "dns-updater.service";
      };
    };
  };
}
