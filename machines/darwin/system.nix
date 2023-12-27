{
  environment.launchDaemons."limit.maxfiles.plist" ={
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
    defaults = {
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

        # Display full POSIX path as Finder window title
        _FXShowPosixPathInTitle = true;

        # Use column view in all Finder windows by default
        # Icon View   : `icnv`
        # List View   : `Nlsv`
        # Column View : `clmv`
        # Cover Flow  : `Flwv`
        FXPreferredViewStyle = "clmnv";

        # show hidden files by default
        # AppleShowAllFiles = true;
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

      CustomUserPreferences ={
        # Add a context menu item for showing the Safari Web Inspector in web views
        WebKitDeveloperExtras = true;

        com.apple.springing ={
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
      CustomUserPreferences={
        "com.apple.Safari" = {
          # Enable the Develop menu and the Web Inspector in Safari
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
          ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled =
            true;
        };
      };

      ###############################################################################
      # Mail                                                                        #
      ###############################################################################

      # Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
      CustomUserPreferences={
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
      ActivityMonitor.ShowCategory = null;

      ###############################################################################
      # Messages                                                                    #
      ###############################################################################

      CustomUserPreferences={
        "com.apple.messageshelper.MessageController" = {
          SOInputLineSettings = {
            # Disable smart quotes as it’s annoying for messages that contain code
            automaticQuoteSubstitutionEnabled = false;
            # Disable continuous spell checking
            continuousSpellCheckingEnabled = false;
          };
        };
      };

      ###############################################################################
      # App Store                                                                   #
      ###############################################################################

      # Disable in-app rating requests from apps downloaded from the App Store.
      CustomUserPreferences={
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
