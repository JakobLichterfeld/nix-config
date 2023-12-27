{ pkgs }:

with pkgs; [
  # General packages for development and system management
  act # Run your GitHub Actions locally

  # Encryption and security tools
  age
  gnupg
  pinentry # GnuPG’s interface to passphrase input
  tor-browser

  # Cloud-related tools and SDKs
  docker
  docker-compose

  # Fonts
  dejavu_fonts
  fira-code-nerdfont

  # Communication Tools
  betterdiscordctl

  # Entertainment Tools
  steam

  # Development tools
  vscode
  wireshark
  john
  shellcheck
  shfmt
  html-tidy
  elixir
  android-studio
  chromedriver
  flutter
  cocoapods
  fastlane
  openssl_3_1
  ruby

  # Python packages
  python39
  python39Packages.virtualenv # globally install virtualenv
  python39Packages.pip # globally install pip

  # infrastructure
  ansible-lint

  gpsbabel
  gpsbabel-gui

  # Writing
  texliveFull
  pandoc
  calibre

  # Image
  geeqie # Image viewer
  digikam # Photo management application

  # Node.js development tools
  nodePackages.nodemon
  nodePackages.prettier
  nodePackages.npm # globally install npm
  nodejs

  # Text and terminal utilities
  binwalk

  # Remote desktop
  teamviewer
  xquartz
  freerdp

  # Other
  tradingview
]
