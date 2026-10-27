{ lib, pkgs, ... }:
{
  # zellij: terminal workspace; interactive SSH logins attach to a persistent session
  environment.systemPackages = [ pkgs.zellij ];

  programs.bash.interactiveShellInit = ''
    if [[ -t 0 && -t 1 ]] &&                                                # has a terminal
       [[ -z "$ZELLIJ" ]] &&                                                # not already inside zellij
       [[ "$(${pkgs.procps}/bin/ps -o args= -p "$PPID")" == sshd* ]]; then # started by sshd, incl. Warp's non-login wrapper shell
      ${lib.getExe pkgs.zellij} attach -c main && exit
    fi
  '';
}
