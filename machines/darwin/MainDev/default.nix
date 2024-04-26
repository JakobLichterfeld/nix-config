{ inputs, pkgs, lib, ... }:
let
  masApps = import ./masApps.nix;
  brews = import ./brews.nix;
  casks = import ./casks.nix;
in
{
  homebrew = {
    masApps = masApps;
    brews = brews;
    casks = casks;
  };

  environment.shellInit = ''
    ulimit -n 2048
    '';


  environment.systemPackages = pkgs.callPackage ./packages.nix {};
}
