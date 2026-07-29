{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
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

  # Username and home directory are derived from the system user by home-manager.
  home.stateVersion = "25.11";

  imports = [
    ../../dots/direnv/default.nix
    ../../dots/fastfetch/default.nix
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
