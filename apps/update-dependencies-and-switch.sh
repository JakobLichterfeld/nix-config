#!/usr/bin/env bash
set -e

SUDO_CMD="${SUDO_WRAPPER:-sudo}"

# ensure running in repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "Not a git repository." >&2
  exit 1
fi
cd "$REPO_ROOT"

echo "[1/5] Updating flake.lock..."
nix --experimental-features 'nix-command flakes' flake update

# ensure there are no other working-tree changes except maybe flake.lock
status_other="$(git status --porcelain | grep -v 'flake.lock' || true)"
if [ -n "$status_other" ]; then
  echo "Refusing to proceed: working tree has changes besides flake.lock:" >&2
  git status --porcelain | sed -n '1,200p' >&2
  exit 1
fi

echo "[2/5] Staging flake.lock..."
git add flake.lock

# ensure only flake.lock is staged
staged="$(git diff --cached --name-only || true)"
if [ -z "$staged" ]; then
  echo "Nothing staged; aborting." >&2
  exit 1
fi
# allow only flake.lock
if [ "$(echo "$staged" | wc -l)" -ne 1 ] || [ "$(echo "$staged" | tr -d '\n')" != "flake.lock" ]; then
  echo "Refusing to commit: staged files are not limited to flake.lock:" >&2
  echo "$staged" >&2
  exit 1
fi

# check that there are no local commits that would be pushed (upstream may be unset)
branch="$(git rev-parse --abbrev-ref HEAD)"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -n "$upstream" ]; then
  outgoing="$(git rev-list --count "${upstream}..${branch}" 2>/dev/null || true)"
  if [ -n "$outgoing" ] && [ "$outgoing" -ne 0 ]; then
    echo "Refusing to push because there are local commits to be pushed (would push more than the flake.lock commit)." >&2
    echo "Run 'git log ${upstream}..${branch}' to inspect." >&2
    exit 1
  fi
fi

echo "[3/5] Committing lockfile..."
git commit -m "chore: update flake.lock with new dependency revisions" -- flake.lock || {
  echo "No commit created (maybe no changes); continuing."
}

echo "[4/5] Pushing lockfile to remote..."
# push only current branch (upstream must exist or will be created)

# Dynamically determine the remote name
REMOTE_NAME=$(git remote | head -n 1)
if [ -z "$REMOTE_NAME" ]; then
  echo "No Git remote found. Please configure a remote repository." >&2
  exit 1
fi

git push --no-verify "$REMOTE_NAME" "$branch"

if [[ "$(uname)" == "Darwin" ]]; then
  echo "[5/5] Rebuilding and switching macOS system..."
  $SUDO_CMD darwin-rebuild switch --flake .#
else
  echo "[5/5] Rebuilding and switching Linux system..."
  nixos-rebuild switch --flake .#
fi
