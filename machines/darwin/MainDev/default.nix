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
in
{
  networking = {
    hostName = machinesSensitiveVars.MainDev.hostName;
  };
  time.timeZone = "Europe/Berlin";

  homebrew = {
    masApps = masApps;
    brews = brews;
    casks = casks;
  };

  environment.shellInit = ''
    ulimit -n 2048
  '';

  environment.systemPackages =
    with inputs.nixpkgs-unstable.legacyPackages."${pkgs.stdenv.hostPlatform.system}";
    pkgs.callPackage ./packages.nix { };
}
