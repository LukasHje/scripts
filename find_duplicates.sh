#!/bin/bash

# find_duplicates.sh
# -------------------
# Author: Lukas Hjernquist / ChatGPT 
# Version: 1.0.0
#
# Finds duplicate media files (with suffixes like ' 2') and moves them to a
# 'to_be_deleted' folder for manual review.
# Supports dry-run mode and scoped execution to a specific subdirectory.
#
# to run script: (first dry-run, controll the .log and validate output)
# --------------------
# bash find_duplicates.sh /mnt/tank/media/Pictures/Favoriter --dry-run
# bash find_duplicates.sh /mnt/tank/media/Pictures/Favoriter

TARGET_DIR="$1"
DRY_RUN=0

if [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=1
fi

if [[ -z "$TARGET_DIR" || ! -d "$TARGET_DIR" ]]; then
    echo "Usage: $0 /path/to/scan [--dry-run]"
    exit 1
fi

LOG_DIR="/mnt/tank/scripts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/find_duplicates_$(date +%Y%m%d_%H%M%S).log"

DUPLICATES_DIR="$TARGET_DIR/to_be_deleted"
mkdir -p "$DUPLICATES_DIR"

echo "--- Duplicate Finder started: $(date) ---" >> "$LOG_FILE"
echo "Scanning: $TARGET_DIR" >> "$LOG_FILE"
[[ $DRY_RUN -eq 1 ]] && echo "[DRY-RUN ENABLED]" >> "$LOG_FILE"

FOUND=0
SKIPPED=0

while IFS= read -r -d '' FILE; do
    BASENAME=$(basename "$FILE")
    DIRNAME=$(dirname "$FILE")
    EXT="${BASENAME##*.}"
    NAME="${BASENAME%.*}"

    # Match pattern like "filename 2.jpg" or "image (2).jpg"
    if [[ "$NAME" =~ .*\ ([0-9]+)$ || "$NAME" =~ .*\([0-9]+\)$ ]]; then
        TARGET="$DUPLICATES_DIR/$BASENAME"
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "(DRY-RUN) ➡️  Would move: $FILE → $TARGET" >> "$LOG_FILE"
        else
            mv "$FILE" "$TARGET"
            echo "➡️  Moved duplicate: $FILE → $TARGET" >> "$LOG_FILE"
        fi
        ((FOUND++))
    else
        ((SKIPPED++))
    fi
done < <(find "$TARGET_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) -print0)

# Summary
echo "--- Summary ---" >> "$LOG_FILE"
echo "✅  Duplicates detected: $FOUND" >> "$LOG_FILE"
echo "✔️  Files ignored:       $SKIPPED" >> "$LOG_FILE"
echo "📁  Destination folder:  $DUPLICATES_DIR" >> "$LOG_FILE"
echo "--- Duplicate Finder completed: $(date) ---" >> "$LOG_FILE"
