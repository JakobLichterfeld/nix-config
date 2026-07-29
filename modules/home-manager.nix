{ inputs, ... }:
{
  # Shared home-manager policy for every machine that manages user profiles.
  # The OS-specific home-manager module itself is imported next to this one.
  home-manager = {
    useGlobalPkgs = true; # makes hm use the system's pkgs value, including its overlays
    useUserPackages = true; # installs hm packages into the system generation instead of ~/.nix-profile
    extraSpecialArgs = { inherit inputs; }; # allows access to flake inputs in hm modules
    backupFileExtension = "bak";
  };
}
