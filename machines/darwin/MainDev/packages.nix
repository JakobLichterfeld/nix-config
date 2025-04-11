{ pkgs }:

with pkgs;
[
  # General packages for development and system management
  act # Run your GitHub Actions locally

  # Cloud-related tools and SDKs
  docker
  docker-compose

  # Development tools
  # john # disabled because of Avast quarantine
  shellcheck
  shfmt
  nixfmt-rfc-style
  html-tidy
  elixir
  chromedriver
  # cocoapods #do not use, use gem install cocoapods
  # fastlane # do not use, use with gem bundler
  openssl_3
  ruby
  rubyPackages.cocoapods
  bundler # Ruby dependency manager
  rubocop # Ruby static code analyzer and formatter
  devenv # Fast, Declarative, Reproducible, and Composable Developer Environments
  nil # Nix Language server: An incremental analysis assistant for writing in Nix

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
  ansible
  ansible-lint

  # Writing
  texliveFull
  pandoc

  # Text and terminal utilities
  binwalk

  # Remote desktop
  freerdp
  scrcpy # Android screen mirroring

]
