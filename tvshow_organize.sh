#!/bin/bash

# tvshow_organize.sh
# -------------------
# Author: Lukas Hjernquist / ChatGPT 
# Version: 1.0.0
#
# Organizes a flat /Tv-shows/ directory by:
# - Detecting series name, season, and episode from common patterns:
#     - S01E01
#     - 01x01
#     - E01 (assumes Season 1)
# - Creating structure: /Tv-shows/Show Name/Show Name_Season 01/filename.ext
# - Handles .mp4, .mkv, .m4v
# - Removes empty folders afterward
# - Supports --dry-run to simulate actions

SOURCE_DIR="/mnt/tank/media/TV-shows"
LOG_DIR="/mnt/tank/scripts/logs"
LOG_FILE="$LOG_DIR/tvshow_organize_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
echo "--- TV Show organize run started: $(date) ---" >> "$LOG_FILE"

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

    SERIES=""
    SEASON=""
    EPISODE=""

    # Match: Show.Name.S01E01 or Show Name S01E01
    if [[ "$NAME_NO_EXT" =~ ^(.+)[.\ _-][Ss]([0-9]{1,2})[Ee]([0-9]{2}) ]]; then
        SERIES="${BASH_REMATCH[1]}"
        SEASON="${BASH_REMATCH[2]}"
        EPISODE="${BASH_REMATCH[3]}"
    # Match: Show.Name.01x01
    elif [[ "$NAME_NO_EXT" =~ ^(.+)[.\ _-]([0-9]{2})x([0-9]{2}) ]]; then
        SERIES="${BASH_REMATCH[1]}"
        SEASON="${BASH_REMATCH[2]}"
        EPISODE="${BASH_REMATCH[3]}"
    # Match: Show.Name.E01 (assume Season 1)
    elif [[ "$NAME_NO_EXT" =~ ^(.+)[.\ _-][Ee]([0-9]{2}) ]]; then
        SERIES="${BASH_REMATCH[1]}"
        SEASON="01"
        EPISODE="${BASH_REMATCH[2]}"
    else
        echo "❌  Could not parse: $BASENAME" >> "$LOG_FILE"
        ((SKIPPED++))
        continue
    fi

    SERIES=$(echo "$SERIES" | sed -E 's/[._]+/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    SERIES_FOLDER="$SOURCE_DIR/$SERIES"
    SEASON_FOLDER="$SERIES_FOLDER/${SERIES}_Season $(printf "%02d" $SEASON)"
    TARGET="$SEASON_FOLDER/$BASENAME"

    mkdir -p "$SEASON_FOLDER"

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

# Remove empty folders
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

# Summary
echo "--- Summary ---" >> "$LOG_FILE"
echo "📁  Organized:              $ORGANIZED" >> "$LOG_FILE"
echo "⚠️  Skipped (file exists):  $SKIPPED" >> "$LOG_FILE"
echo "🗑️  Removed empty folders:  $REMOVED_EMPTY" >> "$LOG_FILE"
if [[ $DRY_RUN -eq 1 ]]; then
    FINAL_COUNT="N/A (dry-run)"
else
    FINAL_COUNT=$(find "$SOURCE_DIR" -mindepth 3 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.m4v" \) | wc -l)
fi
echo "🎯  In correct folders now: $FINAL_COUNT" >> "$LOG_FILE"
echo "--- TV Show organizing completed: $(date) ---" >> "$LOG_FILE"
