#!/bin/bash

# movie_clean_name.sh
# -------------------
# Author: Lukas Hjernquist / ChatGPT 
# Version: 1.1.0

SOURCE_DIR="/mnt/tank/media/media_to_get_added/movies"
LOG_DIR="/mnt/tank/media/media_to_get_added/logs"
LOG_FILE="$LOG_DIR/movie_rename_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"

echo "--- Rename run started: $(date) ---" >> "$LOG_FILE"

COUNT_TOTAL=0
COUNT_RENAMED=0
COUNT_SKIPPED=0

shopt -s nullglob
cd "$SOURCE_DIR" || exit 1

process_movie() {
    local MOVIE_PATH="$1"
    local MOVIE_DIR
    local MOVIE_FILE
    local EXT

    MOVIE_FILE=$(basename "$MOVIE_PATH")
    MOVIE_DIR=$(dirname "$MOVIE_PATH")
    EXT="${MOVIE_FILE##*.}"

    ((COUNT_TOTAL++))

    CLEAN_NAME=$(echo "$MOVIE_FILE" | sed -E \
        -e 's/\.[^.]+$//' \
        -e 's/\[.*?\]//g' \
        -e 's/\(.*?\)//g' \
        -e 's/(\b1080p\b|\b720p\b|\b480p\b)//Ig' \
        -e 's/\b(BluRay|WEBRip|HDRip|DVDRip|BRRip|x264|x265|AAC|MP3|AC3|H264|HEVC|HD|3D|10bit|5\.1|2ch|8CH|H-SBS|PROPER|REMUX|REMASTERED)\b//Ig' \
        -e 's/[^[:alnum:]()0-9]+/ /g' \
        -e 's/ +/ /g' \
        -e 's/^ *| *$//g')

    # Try catch year (even if it's in [] or () )
    if [[ "$MOVIE_FILE" =~ (.+)[[:space:]]*[\(\[]?([0-9]{4})[\)\]]? ]]; then
        YEAR="${BASH_REMATCH[2]}"
    else
        echo "⚠️  Skipped (no year): $MOVIE_FILE" >> "$LOG_FILE"
        ((COUNT_SKIPPED++))
        return
    fi

    # Clean the title some more, remove remaining special characters
    TITLE=$(echo "$CLEAN_NAME" | sed -E "s/$YEAR//g" | sed -E 's/[^[:alnum:] ]+//g' | sed -E 's/ +/ /g' | sed -E 's/^ *| *$//g')
    FINAL_NAME="${TITLE^} (${YEAR})"
    FINAL_FILE="${FINAL_NAME}.${EXT}"
    FINAL_DIR="${SOURCE_DIR}/${FINAL_NAME}"

    # If everything is already correctly named
    if [[ "$MOVIE_DIR" == "$FINAL_DIR" && "$MOVIE_FILE" == "$FINAL_FILE" ]]; then
        echo "✔️  Already correct: $MOVIE_FILE" >> "$LOG_FILE"
        return
    fi

    # Create new folder if it dosen't already exist
    mkdir -p "$FINAL_DIR"

    # Flytta filen dit och döp om
    mv -v "$MOVIE_PATH" "$FINAL_DIR/$FINAL_FILE" >> "$LOG_FILE"

    # Remove old folder if it's empty and is not root
    if [[ "$MOVIE_DIR" != "$SOURCE_DIR" && "$(find "$MOVIE_DIR" -type f | wc -l)" -eq 0 ]]; then
        rmdir "$MOVIE_DIR" 2>/dev/null
    fi

    echo "✅  Renamed and moved: $MOVIE_FILE → $FINAL_DIR/$FINAL_FILE" >> "$LOG_FILE"
    ((COUNT_RENAMED++))
}

# Process: 1. Movies in sub-folders
for DIR in */; do
    for FILE in "$DIR"/*.{mp4,mkv,m4v}; do
        [[ -f "$FILE" ]] && process_movie "$FILE"
    done
done


# Summary
echo "--- Summary ---" >> "$LOG_FILE"
echo "🎞️  Total processed:       $COUNT_TOTAL" >> "$LOG_FILE"
echo "✅  Renamed/moved:         $COUNT_RENAMED" >> "$LOG_FILE"
echo "⚠️  Skipped (no year):     $COUNT_SKIPPED" >> "$LOG_FILE"
echo "--- Rename completed: $(date) ---" >> "$LOG_FILE"
