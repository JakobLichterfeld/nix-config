{
  inputs,
  pkgs,
  lib,
  home-manager,
  ...
}:
let
  masApps = import ./masApps.nix;
  brews = import ./brews.nix;
  casks = import ./casks.nix;
in
{
  imports = [
    ../../modules/cachix
    ./dock
    ./system.nix
  ];
  nix-homebrew = {
    # Install Homebrew under the default prefix
    enable = true;

    # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
    enableRosetta = true;

    # Automatically migrate existing Homebrew installations
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true; # update homebrew on activation of the flake
      cleanup = "zap"; # cleanup all formulae not in the flake
      upgrade = true; # upgrade all formulae on activation of the flake
    };
    brewPrefix = "/opt/homebrew/bin";
    caskArgs = {
      no_quarantine = true;
    };

    masApps = masApps;
    brews = brews;
    casks = casks;
  };

  services.nix-daemon.enable = lib.mkForce true;

  # Setup user, packages, programs
  nix = {
    gc = {
      user = "root";
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # allow packages with unfree licenses
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    with pkgs;
    [
      inputs.agenix.packages."${pkgs.system}".default
    ]
    ++ (import ./packages.nix { inherit pkgs; });

  # Fully declarative dock using the latest from Nix Store
  local.dock.enable = true;
  local.dock.entries = [
    # Finder
    # { path = "/System/Applications/Finder.app/"; }
    # Launchpad
    { path = "/System/Applications/Launchpad.app/"; }
    # Google Chrome
    { path = "/Applications/Google Chrome.app/"; }
    # Warp
    { path = "/Applications/Warp.app/"; }
    # VS Code
    { path = "/Applications/Visual Studio Code.app/"; }
    # Discord
    { path = "/Applications/Discord.app/"; }
    # Mail
    { path = "/Applications/Mail.app/"; }
    # Figma
    { path = "/Applications/Figma.app/"; }
    # App Store
    { path = "/Applications/App Store.app/"; }
    # System Settings
    { path = "/Applications/System Einstellungen.app/"; }
    # Rechner
    { path = "/Applications/Rechner.app/"; }
    # Obsidian
    { path = "/Applications/Obsidian.app/"; }
    # KeepassXC
    { path = "/Applications/KeePassXC.app/"; }
    # Join
    { path = "/Users/jakob/Applications/Chrome Apps.localized/Join.app/"; }
    # Windows App (formerly Microsoft Remote Desktop)
    { path = "/Applications/Windows App.app/"; }
  ];
}
