#!/bin/bash

# movie_restore.sh
# ----------------
# Author: Lukas Hjernquist
# Version: 1.0.0
#
# This script cleans and restores a disorganized /Movies/ directory by:
# - Moving all .mp4 and .mkv files from subdirectories into the root /Movies/ folder
# - Deleting leftover metadata, subtitles, and unwanted files (.json, .jpg, .nfo, .srt, .sub, .DS_Store, etc.)
# - Recursively removing empty folders (including those with only hidden files)
# - Logging all actions and summarizing the cleanup at the end
#
# Safe to run multiple times. It avoids overwriting existing movie files.

SOURCE_DIR="/mnt/tank/media/Movies"
LOG_DIR="/mnt/tank/scripts/logs"
LOG_FILE="$LOG_DIR/movie_restore_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
echo "--- Movie restore run started: $(date) ---" >> "$LOG_FILE"

RESTORED=0
SKIPPED=0
CLEANED=0
VALID_FILMS=0

# Move all .mp4 and .mkv files from subdirs to root
find "$SOURCE_DIR" -mindepth 2 -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | while read -r FILE; do
    BASENAME=$(basename "$FILE")
    TARGET="$SOURCE_DIR/$BASENAME"

    if [[ -f "$TARGET" ]]; then
        echo "⚠️  Skipped (already exists in root): $FILE" >> "$LOG_FILE"
        ((SKIPPED++))
        continue
    fi

    if mv -n "$FILE" "$TARGET" 2>/dev/null; then
        echo "✅  Restored: $FILE → $TARGET" >> "$LOG_FILE"
        ((RESTORED++))
    else
        echo "❌  Failed to restore: $FILE" >> "$LOG_FILE"
        ((SKIPPED++))
    fi

done

# Remove unwanted files (.json, .jpg, .nfo, .srt, .sub, .DS_Store, etc)
find "$SOURCE_DIR" -type f \( -iname "metadata.json" -o -iname "poster.jpg" -o -iname "backdrop.jpg" -o -iname "*.nfo" -o -iname "*.srt" -o -iname "*.sub" -o -iname ".DS_Store" \) -exec rm -v {} \; >> "$LOG_FILE"

# Remove any remaining empty directories recursively (including those with only hidden files)
while :; do
    EMPTY_BEFORE=$(find "$SOURCE_DIR" -type d -empty | wc -l)
    find "$SOURCE_DIR" -depth -type d -exec bash -c 'shopt -s dotglob nullglob; files=($1/*); [[ ${#files[@]} -eq 0 ]] && rmdir "$1"' _ {} \; 2>/dev/null
    EMPTY_AFTER=$(find "$SOURCE_DIR" -type d -empty | wc -l)
    (( DIFF = EMPTY_BEFORE - EMPTY_AFTER ))
    (( CLEANED += DIFF ))
    [[ $DIFF -eq 0 ]] && break
done

# Count valid movies in root
VALID_FILMS=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | wc -l)

# Summary
echo "--- Summary ---" >> "$LOG_FILE"
echo "✅  Restored movies:       $RESTORED" >> "$LOG_FILE"
echo "⚠️  Skipped (conflicts):   $SKIPPED" >> "$LOG_FILE"
echo "🧹  Folders/files cleaned: $CLEANED" >> "$LOG_FILE"
echo "🎬  Valid movies in root:  $VALID_FILMS" >> "$LOG_FILE"
echo "--- Restore completed: $(date) ---" >> "$LOG_FILE"
