{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.mover;
  inherit (builtins) toString map readFile;
  inherit (lib)
    mkIf
    mkEnableOption
    types
    mkOption
    ;
  mergerfs-uncache = pkgs.writeScriptBin "mergerfs-uncache" (readFile ./mergerfs-uncache.py);
  hl = config.homelab;
in
{
  options.services.mover = {
    enable = mkEnableOption "mergerfs-uncache mover script";
    cacheArray = mkOption {
      description = "The drive array to move the data from";
      type = types.str;
      default = "${hl.mounts.fast}";
    };
    backingArray = mkOption {
      description = "The drive array to move the data to";
      type = types.str;
      default = "${hl.mounts.slower}";
    };
    percentageFree = mkOption {
      description = "The target free percentage of the SSD cache array";
      type = types.int;
      apply = old: toString old;
      default = 50;
    };
    excludedPaths = mkOption {
      description = "List of paths that should be excluded from moving";
      type = types.listOf types.str;
      apply =
        old: lib.strings.concatStringsSep " " (map (x: config.services.mover.cacheArray + "/" + x) old);
      default = [ ];
    };
    # user = mkOption {
    #   description = "User to run the script as";
    #   type = types.str;
    #   default = "share";
    # };
    # group = mkOption {
    #   description = "Group to run the script as";
    #   type = types.str;
    #   default = "share";
    # };

  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      mergerfs-uncache
      (pkgs.python312Full.withPackages (ps: with ps; [ aiofiles ]))
    ];

    # security.sudo.extraRules = [
    #   {
    #     users = [ config.services.mover.user ];
    #     commands = [
    #       {
    #         command = "/run/current-system/sw/bin/journalctl --unit=mergerfs-uncache.service *";
    #         options = [ "NOPASSWD" ];
    #       }
    #       {
    #         command = "/run/current-system/sw/bin/chgrp -R ${config.services.mover.group} ${config.services.mover.backingArray}";
    #         options = [ "NOPASSWD" ];
    #       }
    #       {
    #         command = "/run/current-system/sw/bin/chgrp -R ${config.services.mover.group} ${config.services.mover.cacheArray}";
    #         options = [ "NOPASSWD" ];
    #       }
    #       {
    #         command = "/run/current-system/sw/bin/chmod -R u=rwX\\,go=rX ${config.services.mover.backingArray}";
    #         options = [ "NOPASSWD" ];
    #       }
    #       {
    #         command = "/run/current-system/sw/bin/chmod -R u=rwX\\,go=rX ${config.services.mover.cacheArray}";
    #         options = [ "NOPASSWD" ];
    #       }
    #     ];
    #   }
    # ];

    systemd = {
      services.mergerfs-uncache = {
        description = "MergerFS Mover script";
        path = [
          pkgs.rsync
          (pkgs.python312Full.withPackages (ps: with ps; [ aiofiles ]))
          pkgs.systemd
          pkgs.coreutils
          pkgs.gawk
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "/run/current-system/sw/bin/mergerfs-uncache --source ${config.services.mover.cacheArray} --destination ${config.services.mover.backingArray} --target ${config.services.mover.percentageFree} --exclude ${config.services.mover.excludedPaths}"; # --uid ${config.services.mover.user} --gid ${config.services.mover.group}";
          # User = config.services.mover.user;
          # Group = config.services.mover.group;
        };
        onFailure = lib.lists.optionals (config ? tg-notify && config.tg-notify.enable) [
          "tg-notify@%i.service"
        ];
      };
      timers.mergerfs-uncache = {
        wantedBy = [ "multi-user.target" ];
        timerConfig = {
          OnCalendar = "Sat 00:00:00";
          Unit = "mergerfs-uncache.service";
        };
      };
    };
  };
}
