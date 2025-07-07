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

          TMP_OUT="$(mktemp)"
          ${pkgs.snapraid}/bin/snapraid scrub -p ${toString plan} -o ${toString olderThan} > "$TMP_OUT" 2>&1
          CODE=$?

          cat "$TMP_OUT"

          if grep -q "The array appears to be empty" "$TMP_OUT"; then
            echo "[INFO] SnapRAID reports empty array – scrub skipped." >&2
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
