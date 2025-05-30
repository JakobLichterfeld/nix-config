{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.zsh = {
    enable = true;
    autocd = false;

    autosuggestion.enable = true;
    enableCompletion = true;

    history = {
      ignoreDups = true; # no duplicates when scrolling command history
      save = 10000; # how many lines of history to save in memory
      size = 10000; # how many lines of history to keep in memory
      ignorePatterns = [
        "pwd"
        "ls"
        "cd"
      ]; # Remove history data we don't want to see
    };

    shellAliases = {
      # Use difftastic, syntax-aware diffing
      diff = "difft";
      # Always color ls and group directories
      ls = "ls --color=auto";
    };

    initContent = lib.mkBefore ''
      # nix shortcuts
      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }

      # enable frum
      # eval "$(frum init)"

      # TeX
      export PATH="/Library/TeX/texbin:$PATH"

      export GPG_TTY=$(tty)

      # Dart
      export PATH="$PATH:/usr/local/opt/dart/libexec/bin"
      # add dart pub cache to path
      export PATH="$PATH":"$HOME/.pub-cache/bin"

      # Flutter
      # add flutter to path if using manual install
      #export PATH="$PATH":"$HOME/development/flutter/bin"
    '';
  };
}
