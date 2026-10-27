{
  config,
  pkgs,
  lib,
  ...
}:
let
  # GUI prompt on macOS, terminal prompt on Linux where we work over SSH
  pinentry =
    if pkgs.stdenv.isDarwin then
      lib.getExe pkgs.pinentry_mac
    else
      lib.getExe' pkgs.pinentry-curses "pinentry-curses";
in
{
  # gpg warns about unsafe permissions unless its homedir is private, and the
  # links below would otherwise create it with the default umask
  home.activation.createGpgHomedir = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
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
