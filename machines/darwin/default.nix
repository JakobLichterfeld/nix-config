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

  home-manager.nix-darwin = {
    useGlobalPkgs = false; # makes hm use nixos's pkgs value
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; }; # allows access to flake inputs in hm modules
    users.jakob =
      { config, pkgs, ... }:
      {
        nixpkgs.overlays = [
          inputs.nur.overlay
        ];
        home.homeDirectory = lib.mkForce "/Users/jakob";
        shell = pkgs.zsh;

        imports = [
          inputs.nix-index-database.hmModules.nix-index
          inputs.agenix.homeManagerModules.default
          ../../users/jakob/dots.nix
        ];
      };

    backupFileExtension = "bak";
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
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

    # # Turn this on to make command line easier
    # extraOptions = ''
    #   experimental-features = nix-command flakes
    # '';
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # allow packages with unfree licenses
  nixpkgs.config.allowUnfree = true;

  # Enable fonts dir
  fonts.fontDir.enable = true;

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
