#!/usr/bin/env bash
set -e

SUDO_CMD="${SUDO_WRAPPER:-sudo}"

echo "[1/2] Pulling latest config from Git and rebase if needed..."
if [[ "$(uname)" != "Darwin" ]]; then
  cd /etc/nixos
fi
# Use --rebase to maintain a clean, linear history, especially for config updates on target machines.
git pull --rebase

if [[ "$(uname)" == "Darwin" ]]; then
  echo "[2/2] Rebuilding and switching macOS system..."
  $SUDO_CMD darwin-rebuild switch --flake .#
else
  echo "[2/2] Rebuilding and switching Linux system..."
  nixos-rebuild switch --flake .#
fi
