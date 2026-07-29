{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
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
