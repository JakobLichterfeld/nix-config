{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  home = {
    username = "jakob";
    homeDirectory = "/home/jakob";
    stateVersion = "25.11";
  };
in
{
  nixpkgs = {
    overlays =
      [
      ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = home;

  imports = [
    ../../dots/direnv/default.nix
    ../../dots/neofetch/default.nix
    ../../dots/starship/default.nix
    ../../dots/zsh/default.nix
    ./packages.nix
    ./git.nix
  ];

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";
}
