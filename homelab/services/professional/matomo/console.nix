{
  stdenv,
  pkgs,
  writeShellScript,
  php,
  matomoPackage,
  matomoUser,
  matomoStateDir,
  ...
}:

let
  # This is the user-facing command that will be placed in the system's PATH.
  # you can run it for example like:
  # `matomo-console customdimensions:add-custom-dimension --scope=visit`
  # or
  # `matomo-console customdimensions:add-custom-dimension --scope=action`
  consoleScript = writeShellScript "matomo-console" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Define paths from the arguments passed by the Nix derivation.
    MATOMO_CONSOLE_SCRIPT="${matomoPackage}/share/console"
    MATOMO_USER_PATH="${matomoStateDir}"
    MATOMO_USER="${matomoUser}"

    # For transparency, inform the user how the command is being executed.
    echo "Executing Matomo console as user '$MATOMO_USER'..." >&2

    # Use `sudo` to execute the command as the correct user.
    # The `PIWIK_USER_PATH` environment variable is the official, built-in
    # way to tell Matomo where its state directory (which contains config/) is.
    # This is the simplest and most direct way to solve the config file issue.
    # `exec` replaces the current shell process with the `sudo` process.
    exec sudo \
      --user "$MATOMO_USER" \
      PIWIK_USER_PATH="$MATOMO_USER_PATH" \
      "${php}/bin/php" "$MATOMO_CONSOLE_SCRIPT" "$@"
  '';

in
# This derivation places the console script into the system environment.
stdenv.mkDerivation {
  pname = "matomo-console";
  version = "0.1.0";
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    ln -s "${consoleScript}" $out/bin/matomo-console
  '';
}
