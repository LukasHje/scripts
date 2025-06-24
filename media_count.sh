#!/bin/bash

MOVIE_DIR="/mnt/tank/media/Movies"
TV_DIR="/mnt/tank/media/TV-shows"
MUSIC_DIR="/mnt/tank/media/Music"
LOG_DIR="/mnt/tank/scripts/logs"
LOG_FILE="$LOG_DIR/media_count_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
echo "--- Media count run started: $(date) ---" >> "$LOG_FILE"

MOVIES_COUNT=$(find "$MOVIE_DIR" -type f \( -iname "*.mkv" -o -iname "*.m4v" -o -iname "*.mp4" \) | wc -l)
TV_COUNT=$(find "$TV_DIR" -type f \( -iname "*.mkv" -o -iname "*.m4v" -o -iname "*.mp4" \) | wc -l)
MUSIC_COUNT=$(find "$MUSIC_DIR" -type f -iname "*.mp3" | wc -l)

echo "🎬  Movies:      $MOVIES_COUNT" | tee -a "$LOG_FILE"
echo "📺  TV shows:    $TV_COUNT"    | tee -a "$LOG_FILE"
echo "🎵  MP3 songs:   $MUSIC_COUNT" | tee -a "$LOG_FILE"
echo "--- Media count completed: $(date) ---" >> "$LOG_FILE"
