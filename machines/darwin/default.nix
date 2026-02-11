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
  user = "jakob";
  masApps = import ./masApps.nix;
  brews = import ./brews.nix;
  casks = import ./casks.nix;
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
    user = "${user}";

    # Declarative tap management
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "domt4/homebrew-autoupdate" = inputs.homebrew-domt4-autoupdate;
      "krtirtho/homebrew-apps" = inputs.homebrew-spotube;
      "gromgit/homebrew-fuse" = inputs.homebrew-fuse;
      "tabbyml/homebrew-tabby" = inputs.homebrew-tabbyml;
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
    greedyCasks = true; # enable greedy updates

    taps = builtins.attrNames config.nix-homebrew.taps;
    masApps = masApps;
    brews = brews;
    casks = casks;
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
    with inputs.nixpkgs-unstable.legacyPackages."${pkgs.stdenv.hostPlatform.system}";
    [
      inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
    ]
    ++ (import ./packages.nix { inherit pkgs; })
  );

  # Fully declarative dock using the latest from Nix Store
  local = {
    dock.enable = true;
    dock.entries = [
      # position_options:
      # --section [ apps | others ]                                   section of the dock to place the item in

      # folder_options:
      # --view [grid|fan|list|auto]                                   stack view option
      # --display [folder|stack]                                      how to display a folder's icon
      # --sort [name|dateadded|datemodified|datecreated|kind]         sets sorting option for a folder view

      # Finder
      # { path = "/System/Applications/Finder.app/"; }
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
      # { path = "/System/Applications/App Store.app/"; }
      # Applite
      # { path = "/Applications/Applite.app/"; }
      # System Settings
      { path = "/System/Applications/System Settings.app/"; }
      # Calculator
      { path = "/System/Applications/Calculator.app/"; }
      # Obsidian
      { path = "/Applications/Obsidian.app/"; }
      # # KeepassXC
      # { path = "/Applications/KeePassXC.app/"; }
      # Bitwarden
      { path = "/Applications/Bitwarden.app/"; }
      # Join
      { path = "/Users/${user}/Applications/Chrome Apps.localized/Join by Joaoapps.app/"; }
      # Windows App (formerly Microsoft Remote Desktop)
      { path = "/Applications/Windows App.app/"; }
      # DeepL
      { path = "/Applications/DeepL.app/"; }
      # ChatGPT
      { path = "/Applications/ChatGPT.app/"; }
      # Telegram
      { path = "/Applications/Telegram.app/"; }

      # others section

      # Show applications via Finder, as Launchpad has been removed in macOS Tahoe 26.0, as it is now part of Spotlight
      {
        path = "/Applications/";
        section = "others";
        options = "--sort name --view grid --display stack";
      }
      # Downloads
      {
        path = "/Users/${user}/Downloads/";
        section = "others";
        options = "--sort dateadded --view grid --display stack";
      }

    ];
    dock.username = "${user}";
  };

  # Fonts
  fonts.packages = with pkgs; [
    dejavu_fonts
    nerd-fonts.fira-code
  ];
}
