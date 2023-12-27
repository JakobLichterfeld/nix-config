{ config, pkgs, lib, ... }:
{
programs.zsh = {
    enable = true;
    autocd = false;

    enableAutosuggestions = true;
    enableCompletion = true;

    history = {
      ignoreDups = true; #no duplicates when scrolling command history
      save = 1000000;
      size = 1000000;
      ignore = [ "pwd" "ls" "cd" ]; # Remove history data we don't want to see
    };

    initExtraFirst = ''
      # nix shortcuts
      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }

      # Use difftastic, syntax-aware diffing
      alias diff=difft

      # Always color ls and group directories
      alias ls='ls --color=auto'

      # Load Starship
      eval "$(starship init zsh)"
    '';
  };
}
