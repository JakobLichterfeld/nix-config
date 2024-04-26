{ inputs, lib, config, pkgs,  ... }:
let
  home = {
    username = "jakob";
    stateVersion = "23.11";
    };
in
{
  nixpkgs = {
    overlays = [
    ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = home;

  imports = [
      ../../dots/neofetch/default.nix
      ../../dots/zsh/default.nix
      ../../dots/starship/default.nix
      ./packages.nix
      ./git.nix
  ];

  programs.nix-index =
  {
    enable = true;
  };


  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";
  }
