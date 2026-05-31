echo "download the playlist:"
echo ${URL}

yt-dlp \
  -f "bv*+ba[ext=m4a]/bv*+ba/b" \
  --merge-output-format mp4 \
  -o "$(playlist_index)04d_%(title)s.%(ext)s" \
  --download-archive archive.txt \
  --restrict-filenames \
  --embed-metadata --embed-thumbnail \
  --sleep-interval 5 --max-sleep-interval 15 \
  --retries 10 --fragment-retries 10 \
  --ignore-errors \
  ${URL}
