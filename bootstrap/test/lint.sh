#!/usr/bin/env bash
# Syntax check and shellcheck every script in the repository.
#
# Uses the local shellcheck when apt:base has installed it, and falls back to the
# official container image otherwise -- so this works before the bootstrap has
# ever run, which is exactly when you want to lint it.

set -euo pipefail

CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$CONFIG_DIR"

FILES=(bootstrap/bs.sh bootstrap/lib.sh bootstrap/cleanup.sh
       bootstrap/steps/*.sh bootstrap/test/*.sh yt-dlp/*.sh)

echo "==> bash -n"
for f in "${FILES[@]}"; do
  bash -n "$f" || { echo "FAIL: $f does not parse"; exit 1; }
done
echo "OK: all ${#FILES[@]} files parse"

echo "==> shellcheck"
# SC1091: shellcheck resolves `source` relative to its own cwd, which does not
# match how these files are laid out; -x already follows what it can.
if command -v shellcheck >/dev/null; then
  ( cd bootstrap && shellcheck -x -e SC1091 \
      bs.sh lib.sh cleanup.sh steps/*.sh test/*.sh ../yt-dlp/*.sh )
elif command -v docker >/dev/null; then
  # via sh -c so the globs are expanded inside the container, not passed through
  # as literal arguments
  docker run --rm -v "$CONFIG_DIR:/w:ro" -w /w/bootstrap \
    koalaman/shellcheck-alpine:stable \
    sh -c 'shellcheck -x -e SC1091 bs.sh lib.sh cleanup.sh steps/*.sh test/*.sh ../yt-dlp/*.sh'
else
  echo "SKIP: neither shellcheck nor docker available"
  exit 0
fi
echo "OK: shellcheck clean"
