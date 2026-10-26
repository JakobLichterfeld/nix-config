{ lib, pkgs, ... }:
let
  init = ''
    # nix shortcuts
    shell() {
        nix-shell '<nixpkgs>' -A "$1"
    }

    export GPG_TTY=$(tty)
  '';
in
{
  home.shellAliases = {
    # Use difftastic, syntax-aware diffing
    diff = lib.getExe pkgs.difftastic;
    # Color ls output when writing to a terminal
    ls = "ls --color=auto";
  };

  programs.bash.initExtra = init;
  programs.zsh.initContent = lib.mkBefore init;
}
