{ lib, ... }:
{
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 14d";
    persistent = true; # catch up on missed runs of the service when the system was powered down.
  };
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "daily" ];

  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
}
