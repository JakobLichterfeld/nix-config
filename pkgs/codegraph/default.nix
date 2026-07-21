{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "codegraph";
  version = "1.4.1";

  src = fetchurl {
    url = "https://github.com/colbymchenry/codegraph/releases/download/v${version}/codegraph-darwin-arm64.tar.gz";
    hash = "sha256-Smea5aXLn/+QDdWbt4baalgbf2j0z3E73t0TfjR9NNw="; # obtain with: nix hash file --sri <(curl -sL https://github.com/colbymchenry/codegraph/releases/download/v${version}/codegraph-darwin-arm64.tar.gz)
  };

  # Standalone bundle with its own node runtime; the bin/codegraph launcher
  # resolves symlinks itself, so a symlink into libexec is sufficient.
  installPhase = ''
    mkdir -p $out/libexec/codegraph $out/bin
    cp -R . $out/libexec/codegraph/
    ln -s $out/libexec/codegraph/bin/codegraph $out/bin/codegraph
  '';

  dontFixup = true; # keep the bundled node binary untouched (code signature)

  # Meta information
  meta = with lib; {
    description = "Code intelligence CLI/MCP server that indexes a workspace into a SQLite knowledge graph.";
    homepage = "https://github.com/colbymchenry/codegraph";
    license = licenses.mit;
    platforms = [ "aarch64-darwin" ];
    maintainers = [ maintainers.JakobLichterfeld ];
    mainProgram = "codegraph";
  };
}
