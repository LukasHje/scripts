#!/bin/bash

# tvshow_clean_name.sh
# ----------------------
# Cleans and standardizes TV show folder and file names to be Jellyfin-friendly.
# Handles edge cases like inconsistent folder names, extraneous tags, and ensures idempotent behavior.

SOURCE_DIR="/mnt/tank/media/media_to_get_added/tv-shows"
LOG_DIR="/mnt/tank/media/media_to_get_added/logs"
LOG_FILE="$LOG_DIR/tvshow_clean_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false

mkdir -p "$LOG_DIR"

# Enable dry-run mode if --dry-run is passed
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🧪 Dry-run mode activated. No changes will be made." | tee -a "$LOG_FILE"
fi

echo "--- TV show clean run started: $(date) ---" >> "$LOG_FILE"

FOLDER_RENAMED=0
FOLDER_SKIPPED=0
FILE_RENAMED=0
FILE_SKIPPED=0
FOLDERS_REMOVED=0

# Step 1: Clean folder names
while read -r DIR; do
    PARENT=$(dirname "$DIR")
    FOLDER_NAME=$(basename "$DIR")

    CLEAN_SERIES=""
    YEAR=""
    SEASON=""

    # Pattern: Series name + year + season (Sxx or Sxx-Sxx)
    if [[ "$FOLDER_NAME" =~ ^(.+)[._\ -]+([0-9]{4})[._\ -]+[Ss]([0-9]{2})(-S([0-9]{2}))? ]]; then
        CLEAN_SERIES="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
        START_SEASON="${BASH_REMATCH[3]}"
        END_SEASON="${BASH_REMATCH[5]:-${START_SEASON}}"
    elif [[ "$FOLDER_NAME" =~ ^(.+)[._\ -]+[Ss]([0-9]{2}) ]]; then
        CLEAN_SERIES="${BASH_REMATCH[1]}"
        START_SEASON="${BASH_REMATCH[2]}"
        END_SEASON="$START_SEASON"
    else
        ((FOLDER_SKIPPED++))
        continue
    fi

    CLEAN_SERIES=$(echo "$CLEAN_SERIES" | sed -E 's/[._-]+/ /g' | sed -E 's/ +$//')

    for (( SEASON_NUM=10#$START_SEASON; SEASON_NUM<=10#$END_SEASON; SEASON_NUM++ )); do
        SEASON_PADDED=$(printf "%02d" $SEASON_NUM)
        NEW_DIR="$PARENT/$CLEAN_SERIES"
        [[ -n "$YEAR" ]] && NEW_DIR+=" ($YEAR)"
        NEW_DIR+=" Season $SEASON_NUM"

        mkdir -p "$NEW_DIR"

        # Move matching files into this season folder
        while read -r FILE; do
            BASENAME=$(basename "$FILE")
            if [[ "$BASENAME" =~ [Ss]${SEASON_PADDED}[Ee][0-9]{2} ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    echo "🧪 Would move: $FILE → $NEW_DIR" >> "$LOG_FILE"
                else
                    mv -n "$FILE" "$NEW_DIR/"
                    echo "📥 Moved: $FILE → $NEW_DIR" >> "$LOG_FILE"
                fi
            fi
        done < <(find "$DIR" -maxdepth 1 -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.m4v" \))
    done

    # Remove original folder if empty
    if [[ "$DRY_RUN" == false && -d "$DIR" && -z "$(ls -A "$DIR")" ]]; then
        rmdir "$DIR"
        echo "🗑 Removed empty original folder: $DIR" >> "$LOG_FILE"
        ((FOLDERS_REMOVED++))
    fi

    ((FOLDER_RENAMED++))

done < <(find "$SOURCE_DIR" -mindepth 1 -maxdepth 2 -type d)

# Step 2: Rename files inside renamed folders
while read -r FILE; do
    DIRNAME=$(dirname "$FILE")
    BASENAME=$(basename "$FILE")

    if [[ "$DIRNAME" =~ /([^/]+)\ \(([0-9]{4})\)\ Season\ ([0-9]+)$ ]]; then
        SERIES="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
        SEASON="${BASH_REMATCH[3]}"
    else
        ((FILE_SKIPPED++))
        continue
    fi

    if [[ "$BASENAME" =~ ([Ss][0-9]{2}[Ee][0-9]{2}) ]]; then
        EP_TAG="${BASH_REMATCH[1]^}"
    else
        ((FILE_SKIPPED++))
        continue
    fi

    EXT="${BASENAME##*.}"
    CLEAN_NAME="$SERIES ($YEAR) - $EP_TAG.$EXT"
    NEW_PATH="$DIRNAME/$CLEAN_NAME"

    if [[ "$FILE" != "$NEW_PATH" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "🧪 Would rename: $FILE → $NEW_PATH" >> "$LOG_FILE"
            ((FILE_RENAMED++))
        else
            mv -n "$FILE" "$NEW_PATH"
            echo "🎞 Renamed: $FILE → $NEW_PATH" >> "$LOG_FILE"
            ((FILE_RENAMED++))
        fi
    else
        ((FILE_SKIPPED++))
    fi

done < <(find "$SOURCE_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.m4v" \))

# Summary
echo "--- Summary ---" >> "$LOG_FILE"
echo "📁 Folders renamed:        $FOLDER_RENAMED" >> "$LOG_FILE"
echo "📦 Folders skipped:        $FOLDER_SKIPPED" >> "$LOG_FILE"
echo "🗑 Folders removed:        $FOLDERS_REMOVED" >> "$LOG_FILE"
echo "🎞 Files renamed:          $FILE_RENAMED" >> "$LOG_FILE"
echo "❌ Files skipped:          $FILE_SKIPPED" >> "$LOG_FILE"
echo "--- TV show clean completed: $(date) ---" >> "$LOG_FILE"
