{ pkgs }:

with pkgs; [
  # General packages for development and system management
  act # Run your GitHub Actions locally

  # Cloud-related tools and SDKs
  docker
  docker-compose

  # Development tools
  vscode
  wireshark
  # john # disabled because of Avast quarantine
  shellcheck
  shfmt
  nixpkgs-fmt
  html-tidy
  elixir
  chromedriver
  cocoapods
  fastlane
  openssl_3_1
  ruby

  # Python packages
  python313
  python313Packages.virtualenv # globally install virtualenv
  python313Packages.pip # globally install pip

  # Node.js development tools
  nodePackages.nodemon
  nodePackages.prettier
  nodePackages.npm # globally install npm
  nodejs

  # infrastructure
  ansible-lint
  gpsbabel-gui

  # Writing
  texliveFull
  pandoc

  # Text and terminal utilities
  binwalk

  # Remote desktop
  xquartz
  freerdp

]
