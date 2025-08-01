{
  config,
  pkgs,
  lib,
  ...
}:

# Original source: https://gist.github.com/antifuchs/10138c4d838a63c0a05e725ccd7bccdd

with lib;
let
  cfg = config.local.dock;
  inherit (pkgs) stdenv dockutil;
in
{
  options = {
    local.dock = {
      enable = mkOption {
        description = "Enable dock";
        default = stdenv.isDarwin;
      };

      entries = mkOption {
        description = "Entries on the Dock";
        type =
          with types;
          listOf (submodule {
            options = {
              path = lib.mkOption { type = str; };
              section = lib.mkOption {
                type = str;
                default = "apps";
              };
              options = lib.mkOption {
                type = str;
                default = "";
              };
            };
          });
        readOnly = true;
      };

      username = mkOption {
        description = "Username to apply the dock settings to";
        default = config.system.primaryUser;
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable (
    let
      normalize = path: if hasSuffix ".app" path then path + "/" else path;
      entryURI =
        path:
        "file://"
        + (builtins.replaceStrings
          [
            " "
            "!"
            "\""
            "#"
            "$"
            "%"
            "&"
            "'"
            "("
            ")"
          ]
          [
            "%20"
            "%21"
            "%22"
            "%23"
            "%24"
            "%25"
            "%26"
            "%27"
            "%28"
            "%29"
          ]
          (normalize path)
        );
      wantURIs = concatMapStrings (entry: "${entryURI entry.path}\n") cfg.entries;
      createEntries = concatMapStrings (
        entry:
        let
          esc = str: "'" + builtins.replaceStrings [ "'" ] [ "'\\''" ] str + "'";
        in
        "${dockutil}/bin/dockutil --no-restart --add ${esc entry.path} --section ${esc entry.section} ${entry.options}\n"
      ) cfg.entries;
    in
    {
      system.activationScripts.postActivation.text = ''
        echo >&2 ""
        echo >&2 "ℹ️ Dock setup for ${cfg.username} ..."
        sudo -u ${cfg.username} ${pkgs.writeShellScript "dock-setup" ''
          haveURIs="$(${dockutil}/bin/dockutil --list | ${pkgs.coreutils}/bin/cut -f2)"
          if ! diff -q <(echo -n "$haveURIs") <(echo -n '${wantURIs}') >/dev/null; then
            echo >&2 "Dock entries differ, showing changes:"
            diff -wu <(echo -n "$haveURIs") <(echo -n '${wantURIs}') >&2
            echo >&2 "🔨 Resetting Dock ..."
            ${dockutil}/bin/dockutil --no-restart --remove all
            ${createEntries}
            killall Dock
            echo >&2 "✅ Dock setup complete."
          else
            echo >&2 "✅ Dock already up to date."
          fi
        ''}
      '';
    }
  );
}
