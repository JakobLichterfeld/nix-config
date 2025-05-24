{
  config,
  inputs,
  pkgs,
  lib,
  home-manager,
  nix-homebrew,
  ...
}:
let
  masApps = import ./masApps.nix;
  brews = import ./brews.nix;
  casks = import ./casks.nix;

  mkGreedy = cask: cask // { greedy = true; }; # add greedy = true to all casks to enable greedy updates
in
{
  imports = [
    ../../modules/cachix
    ./../../modules/darwin/dock
    ./system.nix
  ];
  nix-homebrew = {
    # Install Homebrew under the default prefix
    enable = true;

    # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
    enableRosetta = true;

    # Automatically migrate existing Homebrew installations
    autoMigrate = true;

    # User owning the Homebrew prefix
    user = "jakob";

    # Declarative tap management
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "domt4/homebrew-autoupdate" = inputs.homebrew-domt4-autoupdate;
      "krtirtho/homebrew-apps" = inputs.homebrew-spotube;
      "gromgit/homebrew-fuse" = inputs.homebrew-fuse;
    };

    # Enable fully-declarative tap management
    #
    # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
    mutableTaps = false;
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

    taps = builtins.attrNames config.nix-homebrew.taps;
    masApps = masApps;
    brews = brews;
    casks = map mkGreedy (casks);
  };

  # Setup user, packages, programs
  nix = {
    gc = {
      #user = "root"; # default since 25.05
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

    settings.trusted-users = [
      "root"
      "@admin"
    ];
  };

  # allow packages with unfree licenses
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = (
    with inputs.nixpkgs-unstable.legacyPackages."${pkgs.system}";
    [
      inputs.agenix.packages."${pkgs.system}".default
    ]
    ++ (import ./packages.nix { inherit pkgs; })
  );

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
    { path = "/System/Applications/Mail.app/"; }
    # Figma
    { path = "/Applications/Figma.app/"; }
    # App Store
    { path = "/System/Applications/App Store.app/"; }
    # Applite
    # { path = "/Applications/Applite.app/"; }
    # System Settings
    { path = "/System/Applications/System Settings.app/"; }
    # Calculator
    { path = "/System/Applications/Calculator.app/"; }
    # Obsidian
    { path = "/Applications/Obsidian.app/"; }
    # KeepassXC
    { path = "/Applications/KeePassXC.app/"; }
    # Join
    { path = "/Users/jakob/Applications/Chrome Apps.localized/Join by Joaoapps.app/"; }
    # Windows App (formerly Microsoft Remote Desktop)
    { path = "/Applications/Windows App.app/"; }
    # DeepL
    { path = "/Applications/DeepL.app/"; }
    # ChatGPT
    { path = "/Applications/ChatGPT.app/"; }
    # Telegram
    { path = "/Applications/Telegram.app/"; }
    # Downloads
    {
      path = "/Users/jakob/Downloads/";
      section = "others";
      options = "--sort dateadded --view grid --display stack";
    }

  ];

  # Fonts
  fonts.packages = with pkgs; [
    dejavu_fonts
    nerd-fonts.fira-code
  ];
}
