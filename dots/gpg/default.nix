{
  config,
  pkgs,
  lib,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # GUI prompt on macOS, terminal prompt on Linux where we work over SSH
  pinentryPackage = if isDarwin then pkgs.pinentry_mac else pkgs.pinentry-curses;
  pinentry =
    if isDarwin then
      lib.getExe pinentryPackage
    else
      lib.getExe' pinentryPackage "pinentry-curses";
in
{
  home.packages =
    with pkgs;
    [
      pinentry-curses # GnuPG’s interface to passphrase input
      # both ship bin/pinentry; lowPrio lets pinentry-curses keep it instead of colliding
      (lib.lowPrio pinentry-tty) # GnuPG’s interface to passphrase input
    ]
    ++ lib.optional isDarwin pinentry_mac; # GnuPG’s interface to passphrase input on Mac

  # gpg warns about unsafe permissions unless its homedir is private, and the
  # links below would otherwise create it with the default umask
  home.activation.createGpgHomedir =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        run mkdir -m700 -p $VERBOSE_ARG "${config.home.homeDirectory}/.gnupg"
      '';

  home.file = {
    # Passphrase prompt, e.g. for `git-crypt unlock`
    ".gnupg/gpg-agent.conf".text = ''
      pinentry-program ${pinentry}
    '';

    # Store public keys in the keyboxd database
    ".gnupg/common.conf".text = ''
      use-keyboxd
    '';
  };
}
