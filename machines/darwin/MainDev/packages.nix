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
  nixfmt # Nix code formatter
  html-tidy
  elixir
  chromedriver
  cocoapods # or use, gem install cocoapods
  # fastlane # do not use, use with gem bundler
  openssl_3
  ruby
  bundler # Ruby dependency manager
  bundix # Creates Nix packages from Gemfiles
  rubocop # Ruby static code analyzer and formatter
  devenv # Fast, Declarative, Reproducible, and Composable Developer Environments
  nil # Nix Language server: An incremental analysis assistant for writing in Nix
  bundletool # Tool for creating and managing Android App Bundles
  fvm # Flutter Version Management: A simple CLI to manage Flutter SDK versions.
  koboldcpp # self-host LLMs; way to run various GGML and GGUF models.

  # Python packages
  python313
  python313Packages.virtualenv # globally install virtualenv
  python313Packages.pip # globally install pip
  python313Packages.pillow # Friendly PIL fork (Python Imaging Library)

  # Node.js development tools
  nodePackages.nodemon
  nodePackages.prettier
  nodePackages.npm # globally install npm
  nodejs
  yarn

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
