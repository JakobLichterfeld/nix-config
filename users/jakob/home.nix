{ inputs, ... }:

{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ./dots.nix
  ];

  home.stateVersion = "25.11";
}
