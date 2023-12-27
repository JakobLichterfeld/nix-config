{ inputs, lib, config, pkgs,  ... }:
let
  home = {
    username = "jakob";
    homeDirectory = "/home/jakob";
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
      ./packages.nix
  ];

  programs.nix-index =
  {
    enable = true;
  };


  programs.git = {
    enable = true;
    userName  = "Jakob Lichterfeld";
    userEmail = "jakob-lichterfeld@gmx.de";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";
  }
