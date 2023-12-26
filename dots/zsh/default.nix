{ config, pkgs, lib, ... }:
{
zsh = {
    enable = true;
    autocd = false;

    initExtraFirst = ''
      #no duplicates when scrolling command history
      setopt HIST_IGNORE_ALL_DUPS

      # Remove history data we don't want to see
      export HISTIGNORE="pwd:ls:cd"

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
