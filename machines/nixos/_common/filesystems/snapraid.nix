{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.snapraid.exclude = [
    "*.unrecoverable"
    "/tmp/"
    "/lost+found/"
  ];

  systemd.services = lib.attrsets.optionalAttrs (config.services.snapraid.enable) {
    snapraid-sync = {
      onFailure = lib.lists.optionals (config ? tg-notify && config.tg-notify.enable) [
        "tg-notify@%i.service"
      ];
      serviceConfig = {
        RestrictNamespaces = lib.mkForce false;
        RestrictAddressFamilies = lib.mkForce "";
      };
    };
    snapraid-scrub =
      let
        plan = config.services.snapraid.scrub.plan or 8;
        olderThan = config.services.snapraid.scrub.olderThan or 10;
        scrubWrapper = pkgs.writeScript "snapraid-scrub-wrapper" ''
          #!${pkgs.runtimeShell}
          LOG="/var/log/snapraid-scrub.log"
          ${pkgs.snapraid}/bin/snapraid scrub -p ${toString plan} -o ${toString olderThan} >> "$LOG" 2>&1
          CODE=$?
          if grep -q "The array appears to be empty" "$LOG"; then
            echo "[INFO] SnapRAID reports empty array - scrub skipped." >> "$LOG"
            exit 0
          fi
          exit $CODE
        '';
      in
      {
        onFailure = lib.lists.optionals (config ? tg-notify && config.tg-notify.enable) [
          "tg-notify@%i.service"
        ];
        serviceConfig = {
          RestrictNamespaces = lib.mkForce false;
          RestrictAddressFamilies = lib.mkForce "";
          ExecStart = lib.mkForce "${scrubWrapper}"; # Use the wrapper script instead of the direct snapraid command to handle the empty array case
        };
      };
  };
}
