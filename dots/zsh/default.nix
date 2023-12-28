{ config, pkgs, lib, ... }:
{
programs.zsh = {
    enable = true;
    autocd = false;

    enableAutosuggestions = true;
    enableCompletion = true;

    history = {
      ignoreDups = true; #no duplicates when scrolling command history
      save = 10000; # how many lines of history to save in memory
      size = 10000; # how many lines of history to keep in memory
      ignorePatterns = [ "pwd" "ls" "cd" ]; # Remove history data we don't want to see
    };

    shellAliases = {
      # Use difftastic, syntax-aware diffing
      diff = "difft";
      # Always color ls and group directories
      ls = "ls --color=auto";
    };

    initExtraFirst = ''
      # nix shortcuts
      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }
    '';
  };
}
