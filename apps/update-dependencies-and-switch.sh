#!/usr/bin/env bash
set -e

SUDO_CMD="${SUDO_WRAPPER:-sudo}"

echo "[1/4] Updating flake.lock..."
nix --experimental-features 'nix-command flakes' flake update

echo "[2/4] Committing lockfile..."
git add flake.lock
git commit -m "chore: update flake.lock with new dependency revisions" || true

echo "[3/4] Pushing to remote..."
git push

if [[ "$(uname)" == "Darwin" ]]; then
  echo "[4/4] Switching to new config with nix-darwin..."
  $SUDO_CMD darwin-rebuild switch --flake .#
else
  echo "[4/4] Not running nix-darwin switch on non-macOS system."
fi
