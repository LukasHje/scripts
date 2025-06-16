# Media Tools
Scripts for organizing and maintaining media libraries, compatible with Jellyfin.
## Contents
- `movie_organize.sh`: Organizes flat movie files into structured folders.
- `tvshow_organize.sh`: Sorts TV show episodes by season and series.
- `movie_restore.sh`: Resets the movie library to a flat structure.
- `find_duplicates.sh`: Finds duplicate photos/videos and stages them for review.
## Usage
```bash
./movie_organize.sh [--dry-run]
./tvshow_organize.sh [--dry-run]
./movie_restore.sh
./find_duplicates.sh /path/to/target --dry-run
