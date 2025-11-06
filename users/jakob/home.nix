{ inputs, ... }:

{
  imports = [
    inputs.agenix.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
    ./dots.nix
  ];

  home.stateVersion = "25.05";
}
