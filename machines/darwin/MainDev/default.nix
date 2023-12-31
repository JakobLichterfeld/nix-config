{ inputs, pkgs, lib, ... }:
let
  ourPythonPackagesForAnsible = pkgs.python311Packages.override
    (oldAttrs: {
      overrides = pkgs.lib.composeManyExtensions [
        (oldAttrs.overrides or (_: _: { }))
        (pfinal: pprev: {
          ansible = pprev.ansible.overridePythonAttrs (old: {
            propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pfinal.boto pfinal.boto3 pfinal.pyyaml ];
            makeWrapperArgs = (old.makeWrapperArgs or []) ++ [ "--prefix PYTHONPATH : $PYTHONPATH" ];
          });
        })
      ];
    });
  ourAnsible =
    (ourPythonPackagesForAnsible.toPythonApplication ourPythonPackagesForAnsible.ansible);

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
