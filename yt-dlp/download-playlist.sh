#!/usr/bin/env bash
# Download a playlist as merged mp4, numbered by playlist position, resumable.
#
#   ./download-playlist.sh <playlist-url>
#   URL=<playlist-url> ./download-playlist.sh
#
# archive.txt in the working directory records what has already been fetched, so
# re-running skips finished items -- keep it next to the files.
#
# Moved here from bootstrap/, which was never the right home: this is not part of
# setting up a machine. yt-dlp and ffmpeg come from bootstrap/tools.tsv and
# bootstrap/apt.tsv respectively.

set -euo pipefail

URL="${1:-${URL:-}}"
: "${URL:?usage: download-playlist.sh <playlist-url>  (or set URL)}"

command -v yt-dlp >/dev/null || { echo "yt-dlp not found; run bootstrap/bs.sh --only tool:yt-dlp" >&2; exit 1; }
command -v ffmpeg >/dev/null || echo "warning: ffmpeg missing, streams cannot be merged (bs.sh --only apt:media)" >&2

echo "downloading playlist: $URL"

yt-dlp \
  -f "bv*+ba[ext=m4a]/bv*+ba/b" \
  --merge-output-format mp4 \
  -o "%(playlist_index)04d_%(title)s.%(ext)s" \
  --download-archive archive.txt \
  --restrict-filenames \
  --embed-metadata --embed-thumbnail \
  --sleep-interval 5 --max-sleep-interval 15 \
  --retries 10 --fragment-retries 10 \
  --ignore-errors \
  "$URL"
