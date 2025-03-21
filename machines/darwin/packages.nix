{ pkgs }:

with pkgs;
[
  # General packages for development and system management
  aspell # Spell checker for many languages
  aspellDicts.en
  aspellDicts.de
  btop
  coreutils
  neofetch
  openssh
  direnv
  curl
  wget
  mkpasswd
  fd # A simple, fast and user-friendly alternative to find

  # Encryption and security tools
  age # A simple, modern and secure encryption tool with small explicit keys, no config options, and UNIX-style composability.
  gnupg
  pinentry # GnuPG’s interface to passphrase input
  keepassxc

  # Fonts
  dejavu_fonts
  fira-code-nerdfont

  # Communication Tools

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
  pstoedit # Translates PostScript and PDF graphics into other vector formats
  xournalpp

  # Image
  exiv2 # Image metadata manipulation tool
  graphicsmagick # Image processing tools collection
  jhead # JPEG Exif header manipulation tool
  jpegoptim # Utility to optimize/compress JPEG files
  inkscape-with-extensions # Vector graphics editor

  # Audio
  normalize # Tool for adjusting the volume of wave files
  timidity # Software synthesizer
  ffmpeg # Audio/video encoder
  audacity # Audio editor

  # Text and terminal utilities
  htop
  hunspell
  hunspellDicts.en_US
  hunspellDicts.de_DE
  iftop
  jq
  ripgrep
  tree
  tmux
  zsh
  starship

  # System tools
  alt-tab-macos # macOS alt-tab replacement
  android-file-transfer
  karabiner-elements # Keyboard customizer for macOS
  mkalias # Create and manage aliases for files and directories

  # Mobile devices
  localsend
]
