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
  pinentry-curses # GnuPG’s interface to passphrase input

  # Fonts
  dejavu_fonts
  fira-code-nerdfont

  # Communication Tools

  # Development tools
  git
  git-crypt
  android-tools

  # File management
  rclone
  unison # Bidirectional file synchronizer

  # Writing
  pstoedit # Translates PostScript and PDF graphics into other vector formats

  # Image
  exiv2 # Image metadata manipulation tool
  graphicsmagick # Image processing tools collection
  jhead # JPEG Exif header manipulation tool
  jpegoptim # Utility to optimize/compress JPEG files

  # Audio
  normalize # Tool for adjusting the volume of wave files
  timidity # Software synthesizer
  ffmpeg # Audio/video encoder

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
  mkalias # Create and manage aliases for files and directories
]
