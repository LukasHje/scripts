#!/bin/bash

# movie_organize.sh
# -------------------
# Author: Lukas Hjernquist / ChatGPT 
# Version: 1.1.0
#
# Description:
# This script organizes movie files in a flat /Movies/ directory into Jellyfin-friendly folders.
# Each movie is placed into its own folder named "Title (Year)" or just "Title" if no year is detected.
# It supports `.mp4`, `.mkv`, and `.m4v` files, and recognizes titles in the format:
#    - Title (Year)
#    - Year - Title - OptionalStuff
#
# Features:
# - Automatically skips already organized files
# - Removes empty folders and associated junk files (.DS_Store, .srt, .sub)
# - Safe to run multiple times (idempotent)
# - Optional --dry-run mode to simulate changes without making them
# - Provides a clear summary log of all actions taken
#
# Usage:
#   ./movie_organize.sh           # Run normally
#   ./movie_organize.sh --dry-run # Simulate actions without moving or deleting anything

SOURCE_DIR="/mnt/tank/media/Movies"
LOG_DIR="/mnt/tank/scripts/logs"
LOG_FILE="$LOG_DIR/movie_organize_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
echo "--- Movie organize run started: $(date) ---" >> "$LOG_FILE"

ORGANIZED=0
SKIPPED=0
REMOVED_EMPTY=0

DRY_RUN=0
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=1
    echo "[DRY-RUN] No files will be moved or deleted." >> "$LOG_FILE"
fi

mapfile -t FILES < <(find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.m4v" \))

for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
    EXT="${BASENAME##*.}"
    NAME_NO_EXT="${BASENAME%.*}"

    # Try pattern: Title (Year)
    if [[ "$NAME_NO_EXT" =~ ^(.+)\ \((19[0-9]{2}|20[0-9]{2})\)$ ]]; then
        TITLE="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
    # Try pattern: Year - Title (e.g. 1928 - Mickey Mouse - Steamboat Willie)
    elif [[ "$NAME_NO_EXT" =~ ^(19[0-9]{2}|20[0-9]{2})[[:space:]]*-+[[:space:]]*(.+)$ ]]; then
        YEAR="${BASH_REMATCH[1]}"
        TITLE="${BASH_REMATCH[2]}"
    else
        # No year found
        TITLE="$NAME_NO_EXT"
        YEAR=""
    fi

    # Clean title
    TITLE=$(echo "$TITLE" | sed -E 's/[._]+/ /g' | sed -E "s/[^[:alnum:] ()'-]+//g" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

    # Final folder name
    if [[ -n "$YEAR" ]]; then
        FOLDER="$SOURCE_DIR/$TITLE ($YEAR)"
        TARGET="$FOLDER/$TITLE ($YEAR).$EXT"
    else
        FOLDER="$SOURCE_DIR/$TITLE"
        TARGET="$FOLDER/$TITLE.$EXT"
    fi

    mkdir -p "$FOLDER"

    if [[ ! -f "$TARGET" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "(DRY-RUN) 📁  Would move: $BASENAME → $TARGET" >> "$LOG_FILE"
        else
            mv "$FILE" "$TARGET"
            echo "📁  Organized: $BASENAME → $TARGET" >> "$LOG_FILE"
        fi
        ((ORGANIZED++))
    else
        echo "⚠️  Skipped (target exists): $BASENAME" >> "$LOG_FILE"
        ((SKIPPED++))
    fi

done

# Remove empty or near-empty folders
while IFS= read -r -d '' DIR; do
    if find "$DIR" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.m4v' \) | grep -q .; then
        continue
    fi
    find "$DIR" -type f \( -iname ".DS_Store" -o -iname "*.srt" -o -iname "*.sub" \) -delete
    if [ -z "$(find "$DIR" -mindepth 1 -print -quit)" ]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "(DRY-RUN) 🗑️  Would remove empty folder: $DIR" >> "$LOG_FILE"
        else
            rm -r "$DIR"
            echo "🗑️  Removed empty folder: $DIR" >> "$LOG_FILE"
        fi
        ((REMOVED_EMPTY++))
    fi
done < <(find "$SOURCE_DIR" -mindepth 1 -type d -print0)

# Final summary
echo "--- Summary ---" >> "$LOG_FILE"
echo "📁  Organized:              $ORGANIZED" >> "$LOG_FILE"
echo "⚠️  Skipped (file exists):  $SKIPPED" >> "$LOG_FILE"
echo "🗑️  Removed empty folders:  $REMOVED_EMPTY" >> "$LOG_FILE"

if [[ $DRY_RUN -eq 1 ]]; then
    FINAL_COUNT="N/A (dry-run)"
else
    FINAL_COUNT=$(find "$SOURCE_DIR" -mindepth 2 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.m4v" \) | wc -l)
fi

echo "🎯  In correct folders now: $FINAL_COUNT" >> "$LOG_FILE"
echo "--- Organizing completed: $(date) ---" >> "$LOG_FILE"
