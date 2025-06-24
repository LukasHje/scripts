#!/bin/bash

# ================================
# Script: movie_organizer_yyyyTitle.sh
# Description:
#   - Renames movie files with format:
#       YEAR.TITLE.1920x...mkv e.g. 2022.Lightyear.1920x804.BDRip.x264.DTS-HD.MA.mkv
#   - Extracts everything between YEAR. and .1920x as the title
#   - Result: Title (YEAR).mkv
#   - Moves each file into folder: Title (YEAR)
#
# Usage:
#   bash movie_organize_small.sh                → processes current directory
#   bash movie_organize_small.sh /path/to/dir   → processes specified directory
# ================================

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: directory '$TARGET_DIR' does not exist."
    exit 1
fi

cd "$TARGET_DIR" || exit 1

# File extensions to process
exts="mkv mp4 avi mov m4v"

# Loop through each extension
for ext in $exts; do
    for file in *.$ext; do
        [[ -e "$file" ]] || continue

        # Extract year
        year=$(echo "$file" | cut -d. -f1)

        # Extract title between year. and resolution marker
        title_raw=$(echo "$file" | sed -n "s/^$year\.\(.*\)\.\(1920x\|2160x\|1280x\|1080p\|720p\).*/\1/p")

        # Skip if pattern not matched
        if [[ -z "$title_raw" ]]; then
            echo "⚠️ Skipping: $file (pattern not matched)"
            continue
        fi

        # Replace dots with spaces
        title_clean=$(echo "$title_raw" | tr '.' ' ')

        # Compose final names
        clean_name="${title_clean} (${year})"
        new_filename="${clean_name}.${ext}"

        mkdir -p "$clean_name"
        mv "$file" "$clean_name/$new_filename"

        echo "✅ $file → $clean_name/$new_filename"
    done
done
