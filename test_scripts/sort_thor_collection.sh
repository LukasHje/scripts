#!/bin/bash

API_KEY="49cd26011cc9b4c26c0a2dd17c44c221"
SOURCE_DIR="/mnt/tank/media/Movies/Thor (2011)"
DEST_DIR="/mnt/tank/media/Movies"
LOG_FILE="$DEST_DIR/_thor_test_sort.log"

echo "--- Thor metadata sort run: $(date) ---" >> "$LOG_FILE"

find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | while read -r FILE; do
    BASENAME=$(basename "$FILE")
    EXT="${BASENAME##*.}"
    NAME_NO_EXT="${BASENAME%.*}"

    # Prepare search query
    QUERY=$(echo "$NAME_NO_EXT" | sed -E 's/[._]+/ /g' | sed 's/  */ /g')
    SEARCH=$(echo "$QUERY" | sed 's/ /+/g')

    # TMDb search
    RESPONSE=$(curl -s "https://api.themoviedb.org/3/search/movie?api_key=$API_KEY&query=$SEARCH")
    TITLE=$(echo "$RESPONSE" | jq -r '.results[0].title')
    YEAR=$(echo "$RESPONSE" | jq -r '.results[0].release_date' | cut -d '-' -f1)
    MOVIE_ID=$(echo "$RESPONSE" | jq -r '.results[0].id')

    if [[ "$TITLE" == "null" || -z "$YEAR" ]]; then
        echo "❌ No TMDb match for: $BASENAME" >> "$LOG_FILE"
        continue
    fi

    CLEAN_TITLE=$(echo "$TITLE" | tr -cd '[:alnum:] .()-')
    DIR_NAME="$DEST_DIR/$CLEAN_TITLE ($YEAR)"
    FILE_NAME="$CLEAN_TITLE ($YEAR).$EXT"
    DEST_FILE="$DIR_NAME/$FILE_NAME"

    mkdir -p "$DIR_NAME"

    # Move movie file if not already there
    if [[ ! -f "$DEST_FILE" ]]; then
        mv "$FILE" "$DEST_FILE"
        echo "✅ Moved: $BASENAME → $DEST_FILE" >> "$LOG_FILE"
    fi

    # Check and fetch metadata
    if [[ ! -f "$DIR_NAME/metadata.json" ]]; then
        DETAILS=$(curl -s "https://api.themoviedb.org/3/movie/$MOVIE_ID?api_key=$API_KEY&language=en-US")
        echo "$DETAILS" | jq '.' > "$DIR_NAME/metadata.json"
        echo "📄 metadata.json created" >> "$LOG_FILE"
    fi

    # Poster
    if [[ ! -f "$DIR_NAME/poster.jpg" ]]; then
        POSTER=$(curl -s "https://api.themoviedb.org/3/movie/$MOVIE_ID?api_key=$API_KEY" | jq -r '.poster_path')
        if [[ "$POSTER" != "null" ]]; then
            curl -s "https://image.tmdb.org/t/p/w500$POSTER" -o "$DIR_NAME/poster.jpg"
            echo "🖼 poster.jpg downloaded" >> "$LOG_FILE"
        fi
    fi

    # Backdrop
    if [[ ! -f "$DIR_NAME/backdrop.jpg" ]]; then
        BACKDROP=$(curl -s "https://api.themoviedb.org/3/movie/$MOVIE_ID?api_key=$API_KEY" | jq -r '.backdrop_path')
        if [[ "$BACKDROP" != "null" ]]; then
            curl -s "https://image.tmdb.org/t/p/w780$BACKDROP" -o "$DIR_NAME/backdrop.jpg"
            echo "🌄 backdrop.jpg downloaded" >> "$LOG_FILE"
        fi
    fi
done
