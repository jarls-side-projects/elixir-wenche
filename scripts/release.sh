#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

NEW_VERSION="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CURRENT_VERSION="$(grep -E '^\s*@version\s+"' mix.exs | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
  echo "mix.exs already at version $NEW_VERSION — skipping clean/bump/commit/push."
else
  echo "Bumping $CURRENT_VERSION -> $NEW_VERSION"

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit or stash before releasing." >&2
    exit 1
  fi

  mix deps.clean --all
  rm -rf _build deps
  mix deps.get

  sed -i -E "s/^(\s*@version\s+\")[^\"]+(\")/\1${NEW_VERSION}\2/" mix.exs

  git add mix.exs
  git commit -m "Release v${NEW_VERSION}"
  git push
fi

mix hex.publish
