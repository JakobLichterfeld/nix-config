{ pkgs }:

with pkgs; [
  # General packages for development and system management
  aspell # Spell checker for many languages
  aspellDicts.en
  aspellDicts.de
  btop
  coreutils
  killall
  neofetch
  openssh
  direnv
  curl
  wget
  mkpasswd
  fd #A simple, fast and user-friendly alternative to find
  warp-terminal

  # Encryption and security tools
  gnupg
  pinentry # GnuPG’s interface to passphrase input
  keepassxc
  zerotierone

  # Fonts
  dejavu_fonts
  fira-code-nerdfont

  # Browsers
  google-chrome
  brave

  # Communication Tools
  discord
  slack
  telegram-desktop
  zoom-us
  signal-desktop

  # Development tools
  git
  git-crypt
  android-tools
  meld

  # infrastructure
  ansible


  # File management
  rclone
  unison # Bidirectional file synchronizer

  # Writing
  klavaro # Free touch typing tutor program
  pstoedit # Translates PostScript and PDF graphics into other vector formats
  languagetool
  pdfsam-basic
  xournalpp
  adobe-reader
  libreoffice

  # Image
  exiv2 # Image metadata manipulation tool
  graphicsmagick # Image processing tools collection
  jhead # JPEG Exif header manipulation tool
  sbclPackages.jpeg-turbo # JPEG image manipulation library
  jpegoptim # Utility to optimize/compress JPEG files
  gimp # GNU Image Manipulation Program
  inkscape # Vector graphics editor
  luminanceHDR # HDR imaging application
  hugin # Panorama photo stitcher

  # Audio
  normalize # Tool for adjusting the volume of wave files
  timidity # Software synthesizer
  spotify # Music streaming service
  ffmpeg # Audio/video encoder
  audacity # Audio editor
  picard # MusicBrainz tagger

  # Video
  vlc # Media player
  obs-studio

  # Text and terminal utilities
  htop
  hunspell
  hunspellDicts.de_DE
  iftop
  jq
  ripgrep
  tree
  tmux
  zsh
  starship

  # Remote desktop
  teamviewer

  # System tools
  alt-tab-macos
  rectangle
  android-file-transfer
  karabiner-elements # Keyboard customizer for macOS
]
