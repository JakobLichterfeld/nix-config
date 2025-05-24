{
  inputs,
  pkgs,
  lib,
  machinesSensitiveVars,
  ...
}:
let
  masApps = import ./masApps.nix;
  brews = import ./brews.nix;
  casks = import ./casks.nix;

  mkGreedy = cask: cask // { greedy = true; }; # add greedy = true to all casks to enable greedy updates
in
{
  networking = {
    hostName = machinesSensitiveVars.MainDev.hostName;
  };
  time.timeZone = "Europe/Berlin";

  homebrew = {
    masApps = masApps;
    brews = brews;
    casks = map mkGreedy (casks);
  };

  environment.shellInit = ''
    ulimit -n 2048
  '';

  environment.systemPackages =
    with inputs.nixpkgs-unstable.legacyPackages."${pkgs.system}";
    pkgs.callPackage ./packages.nix { };
}
