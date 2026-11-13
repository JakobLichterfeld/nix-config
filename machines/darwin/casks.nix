[
  # Clipboard-manager
  { name = "maccy"; }

  # Communication Tools
  { name = "microsoft-teams"; }
  { name = "whatsapp"; }
  { name = "telegram"; }
  { name = "signal"; }
  { name = "threema"; }
  { name = "discord"; }
  { name = "slack"; }
  { name = "zoom"; }

  # Development
  { name = "meld"; } # Visual diff and merge tool

  # Design Tools
  { name = "figma"; }
  { name = "sketch"; }
  { name = "rayon"; } # AI-powered drawing for interior design and architecture

  # File Sharing
  { name = "google-drive"; }
  { name = "rsyncui"; }
  { name = "syncthing-app"; } # Syncthing GUI (syncthing-macos)

  # Security
  { name = "avast-security"; }
  { name = "keepassxc"; } # Password manager
  { name = "bitwarden"; } # Password manager

  # System Tools
  { name = "applite"; }
  { name = "alt-tab"; } # Enable Windows-like alt-tab
  {
    name = "macfuse";
    greedy = true; # Homebrew cannot detect that the installed version is outdated; without greedy it never upgrades this cask
  }
  { name = "warp"; } # warp terminal
  { name = "rectangle"; } # Move and resize windows in macOS using keyboard shortcuts or snap areas
  { name = "stats"; } # system monitor in mac menu bar

  # Network
  { name = "zerotier-one"; }

  # Browsers
  { name = "google-chrome"; }
  {
    name = "brave-browser";
    greedy = true; # Homebrew cannot detect that the installed version is outdated; without greedy it never upgrades this cask
  }

  # Writing
  { name = "pdfsam-basic"; }
  {
    name = "adobe-acrobat-reader";
    greedy = true; # Homebrew cannot detect that the installed version is outdated; without greedy it never upgrades this cask
  }
  { name = "libreoffice"; }
  { name = "libreoffice-language-pack"; }
  { name = "microsoft-auto-update"; }
  { name = "deepl"; }
  { name = "xournal++"; } # handwriting Notetaking software with PDF annotation support

  # Image
  { name = "luminance-hdr"; } # HDR imaging application
  { name = "hugin"; } # Panorama photo stitcher
  { name = "imageoptim"; } # Image optimizer
  { name = "inkscape"; } # Vector graphics editor
  { name = "gimp"; } # GNU Image Manipulation Program
  { name = "flowvision"; } # Image viewer

  # Audio
  { name = "audacity"; } # Audio editor
  { name = "musicbrainz-picard"; } # MusicBrainz tagger
  { name = "spotify"; } # Music streaming service
  { name = "krtirtho/apps/spotube"; } # Open source Spotify client, via krtirtho/homebrew-apps

  # Video
  { name = "iina"; }
  { name = "obs"; }
  { name = "yattee"; } # Privacy-friendly YouTube frontend

  # Remote Desktop
  {
    name = "teamviewer";
    greedy = true; # Homebrew cannot detect that the installed version is outdated; without greedy it never upgrades this cask
  }
  { name = "rustdesk"; }

  # Mobile devices
  { name = "android-file-transfer"; }
  { name = "localsend"; } # cross-platform alternative to AirDrop

  # Marketing
  { name = "google-ads-editor"; }

  # AI
  { name = "chatgpt"; } # ChatGPT desktop app
  { name = "claude"; } # Claude AI desktop app
]
