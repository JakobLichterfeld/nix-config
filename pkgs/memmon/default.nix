{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "memmon";
  version = "1.5";

  src = fetchurl {
    url = "https://github.com/relikd/Memmon/releases/download/v${version}/Memmon_v${version}.tar.gz";
    sha256 = "0v7fx2c7bdiahglpxnrv5m50w1xvimk0gmcq79f1vqgpv77wd83c"; # obtain with: nix-prefetch-url https://github.com/relikd/Memmon/releases/download/v${version}/Memmon_v${version}.tar.gz
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/Applications
    cp -R Memmon.app $out/Applications/
  '';

  # Meta information
  meta = with lib; {
    description = "A simple daemon that restores your window positions on external monitors on macOS.";
    homepage = "https://github.com/relikd/Memmon";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [ maintainers.JakobLichterfeld ];
  };
}
