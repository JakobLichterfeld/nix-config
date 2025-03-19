{
  environment.launchDaemons."limit.maxfiles.plist" = {
    enable = true;
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      <key>Label</key>
      <string>limit.maxfiles</string>
      <key>ProgramArguments</key>
      <array>
      <string>launchctl</string>
      <string>limit</string>
      <string>maxfiles</string>
      <string>524288</string>
      <string>524288</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>ServiceIPC</key>
      <false/>
      </dict>
      </plist>
    '';
  };
  system = {
    stateVersion = 4;

    # link nix installed applications to /Applications
    # This results in the apps installed by nix to be available in spotlight search as well
    activationScripts.applications.text =
      let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
      pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';

    defaults = {
      loginwindow.guestEnabled = false; # Disable the guest account

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
      finder = {
        # When performing a search, search the current folder by default
        # This Mac       : `SCev`
        # Current Folder : `SCcf`
        # Previous Scope : `SCsp`
        FXDefaultSearchScope = "SCcf";

        #show all filename extensions
        AppleShowAllExtensions = true;

        # Disable the warning when changing a file extension
        FXEnableExtensionChangeWarning = false;

        # show status bar
        ShowStatusBar = true;

        # show path bar
        ShowPathBar = true;

        # Display full POSIX path as Finder window title
        _FXShowPosixPathInTitle = true;

        # Use column view in all Finder windows by default
        # Icon View   : `icnv`
        # List View   : `Nlsv`
        # Column View : `clmv`
        # Cover Flow  : `Flwv`
        FXPreferredViewStyle = "clmnv";

      };
      CustomUserPreferences = {
        "com.apple.finder" = {
          # Set Home as the default location for new Finder windows
          # Computer     : "PfCm"
          # Volume       : "PfVo"
          # $HOME        : "PfHm"
          # Desktop      : "PfDe"
          # Documents    : "PfDo"
          # All My Files : "PfAF"
          # Other…       : "PfLo"
          # For other paths, use `PfLo` and `file:///full/path/here/`
          cNewWindowTarget = "PfHm";
          # NewWindowTargetPath = "file://${HOME}/Desktop/";

          # Show icons for hard drives, servers, and removable media on the desktop
          ShowExternalHardDrivesOnDesktop = true;
          ShowHardDrivesOnDesktop = true;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;

          # allow text selection in Quick Look
          QLEnableTextSelection = true;

          # show hidden files by default
          # AppleShowAllFiles = true;
        };

      };

      dock = {
        # Dock on the left
        orientation = "left";

        # Auto hide dock
        autohide = true;

        # Speed up Dock show/hide animation
        autohide-delay = 0.08;
        autohide-time-modifier = 0.08;

        # Make Dock icons of hidden applications translucent
        showhidden = true;

        # Set the icon size of Dock items
        tilesize = 128;
        magnification = false;

        # Speed up Mission Control animations
        expose-animation-duration = 0.1;

        # Hot corners
        # Possible values:
        #  0: no-op
        #  2: Mission Control
        #  3: Show application windows
        #  4: Desktop
        #  5: Start screen saver
        #  6: Disable screen saver
        #  7: Dashboard
        # 10: Put display to sleep
        # 11: Launchpad
        # 12: Notification Center

        # Top left screen corner → Mission Control (All windows)
        wvous-tl-corner = 2;

        # Bottom right screen corner → Desktop
        wvous-br-corner = 4;

        # Bottom Left screen corner -> show Application Windows
        wvous-bl-corner = 3;
      };
      NSGlobalDomain = {
        ###############################################################################
        # General UI/UX                                                               #
        ###############################################################################
        AppleICUForce24HourTime = true; # Use 24 hour time
        "com.apple.sound.beep.volume" = 0.000;
        # Expand save panel by default
        NSNavPanelExpandedStateForSaveMode = true;

        # Expand print panel by default
        PMPrintingExpandedStateForPrint = true;

        # Save to disk (not to iCloud) by default
        NSDocumentSaveNewDocumentsToCloud = false;

        ###############################################################################
        # Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
        ###############################################################################
        # Set a blazingly fast keyboard repeat rate, and make it happen more quickly.
        # (The KeyRepeat option requires logging out and back in to take effect.)
        InitialKeyRepeat = 15;
        KeyRepeat = 2;

        # Disable smart quotes as they’re annoying when typing code
        NSAutomaticQuoteSubstitutionEnabled = false;

        # Disable smart dashes as they’re annoying when typing code
        NSAutomaticDashSubstitutionEnabled = false;

        # Disable press-and-hold for keys in favor of key repeat
        ApplePressAndHoldEnabled = false;

        # Disable auto-correct
        NSAutomaticSpellingCorrectionEnabled = false;

      };

      CustomUserPreferences = {
        NSGlobalDomain = {
          # Add a context menu item for showing the Safari Web Inspector in web views
          WebKitDeveloperExtras = true;
        };

        "com.apple.springing" = {
          # Enable spring loading for directories
          enabled = true;

          # Remove the spring loading delay for directories
          delay = 0.1;
        };
      };

      # Automatically quit printer app once the print jobs complete
      CustomUserPreferences = {
        "com.apple.print.PrintingPrefs" = {
          QuitWhenFinished = true;
        };
      };

      CustomUserPreferences = {
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network volumes
          DSDontWriteNetworkStores = true;
        };
      };

      # Enable the 'reduce transparency' option. Save GPU cycles.
      universalaccess.reduceTransparency = true;

      ###############################################################################
      # Screen                                                                      #
      ###############################################################################
      # Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
      screencapture.type = "png";

      # Disable shadow in screenshots
      screencapture.disable-shadow = true;

      ###############################################################################
      # Safari & WebKit                                                             #
      ###############################################################################
      CustomUserPreferences = {
        "com.apple.Safari" = {
          # Enable the Develop menu and the Web Inspector in Safari
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
          WebKit2DeveloperExtrasEnabled = true;
        };
      };

      ###############################################################################
      # Mail                                                                        #
      ###############################################################################

      # Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
      CustomUserPreferences = {
        "com.apple.mail" = {
          AddressesIncludeNameOnPasteboard = false;
        };
      };

      ###############################################################################
      # Activity Monitor                                                            #
      ###############################################################################

      # Show the main window when launching Activity Monitor
      ActivityMonitor.OpenMainWindow = true;

      # Show all processes in Activity Monitor
      # Change which processes to show.
      # * 100: All Processes
      # * 101: All Processes, Hierarchally
      # * 102: My Processes
      # * 103: System Processes
      # * 104: Other User Processes
      # * 105: Active Processes
      # * 106: Inactive Processes
      # * 107: Windowed Processes
      ActivityMonitor.ShowCategory = 100;

      ###############################################################################
      # Messages                                                                    #
      ###############################################################################

      CustomUserPreferences = {
        "com.apple.messageshelper.MessageController SOInputLineSettings" = {
          # Disable smart quotes as it’s annoying for messages that contain code
          automaticQuoteSubstitutionEnabled = false;
          # Disable continuous spell checking
          continuousSpellCheckingEnabled = false;
        };
      };

      ###############################################################################
      # App Store                                                                   #
      ###############################################################################

      # Disable in-app rating requests from apps downloaded from the App Store.
      CustomUserPreferences = {
        "com.apple.appstore" = {
          InAppReviewEnabled = 0;
        };
      };
    };

    activationScripts.postUserActivation.text = ''
      # Following line should allow us to avoid a logout/login cycle
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      launchctl stop com.apple.Dock.agent
      launchctl start com.apple.Dock.agent
    '';
  };
}
