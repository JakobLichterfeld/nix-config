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
      commit.gpgsign = true;
      gpg.format = "ssh";
    };
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";
  }
