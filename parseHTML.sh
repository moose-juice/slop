#!/bin/zsh
#
# Placeholder script for downloading the latest versioned file
# Replace or expand the MAIN section as needed
#

set -euo pipefail

######################################################################
# Function: download_latest_versioned_file
# Description:
#   Given a base URL containing versioned directories and a filename
#   prefix, detects the newest version by timestamp, finds a file
#   beginning with that prefix, downloads it, and returns its full path.
######################################################################

download_latest_versioned_file() {
    local BASE_URL="$1"       # e.g. https://example.com/releases/
    local FILE_BASE="$2"      # e.g. app-macos-arm64
    local TMPDIR
    TMPDIR=$(mktemp -d)

    # Fetch the index page
    local HTML
    HTML=$(curl -sSL "$BASE_URL")

    # Extract version rows
    local INDEX_LINES
    INDEX_LINES=$(echo "$HTML" | grep -E '<a href="([0-9]+\.)+[0-9]+/">' )
    if [[ -z "$INDEX_LINES" ]]; then
        echo "ERROR: No version directories found at $BASE_URL" >&2
        return 1
    fi

    # Parse versions + timestamps
    local VERSION_LIST=()
    local line version timestamp

    while IFS= read -r line; do
        version=$(echo "$line" | sed -E 's/.*href="([0-9.]+)\/".*/\1/')
        timestamp=$(echo "$line" | sed -E 's#.*</a>[[:space:]]*([^<]+)-.*#\1#' | xargs)

        [[ -n "$version" && -n "$timestamp" ]] && VERSION_LIST+=("${version}|${timestamp}")
    done <<< "$INDEX_LINES"

    # Determine newest version by timestamp
    local LATEST_VERSION=""
    local LATEST_TS_EPOCH=0
    local item ver ts epoch

    for item in "${VERSION_LIST[@]}"; do
        ver="${item%%|*}"
        ts="${item#*|}"

        epoch=$(date -j -f "%d-%b-%Y %H:%M" "$ts" "+%s" 2>/dev/null || echo "")

        if [[ -n "$epoch" && "$epoch" -gt "$LATEST_TS_EPOCH" ]]; then
            LATEST_TS_EPOCH="$epoch"
            LATEST_VERSION="$ver"
        fi
    done

    if [[ -z "$LATEST_VERSION" ]]; then
        echo "ERROR: Unable to determine latest version" >&2
        return 1
    fi

    local LATEST_URL="${BASE_URL%/}/$LATEST_VERSION/"
    local VERSION_HTML
    VERSION_HTML=$(curl -sSL "$LATEST_URL")

    # Find a file that matches prefix
    local FILE_LINES fname FILE_URL
    FILE_LINES=$(echo "$VERSION_HTML" | grep -E '<a href=')

    while IFS= read -r line; do
        fname=$(echo "$line" | sed -E 's/.*href="([^"]+)".*/\1/')

        [[ "$fname" == */ ]] && continue  # skip directories

        if [[ "$fname" == ${FILE_BASE}* ]]; then
            FILE_URL="${LATEST_URL}${fname}"
            break
        fi
    done <<< "$FILE_LINES"

    if [[ -z "$FILE_URL" ]]; then
        echo "ERROR: No file found matching prefix '$FILE_BASE' in version $LATEST_VERSION" >&2
        return 1
    fi

    # Download file using original filename
    (
        cd "$TMPDIR"
        curl -sSL -O --remote-header-name "$FILE_URL"
    )

    # Find downloaded file
    local DOWNLOADED_FILE
    DOWNLOADED_FILE=$(find "$TMPDIR" -type f -maxdepth 1 | head -1)

    echo "$DOWNLOADED_FILE"
}

######################################################################
# MAIN (Placeholder)
######################################################################

main() {
    echo "Placeholder main function"
    echo "Modify this section to integrate into your script."

    # Example usage:
    # BASE_URL="https://example.com/downloads/"
    # FILE_PREFIX="myapp-macos-arm64"
    #
    # downloaded_file=$(download_latest_versioned_file "$BASE_URL" "$FILE_PREFIX")
    # echo "Downloaded to: $downloaded_file"

    echo "No operations performed. Script is ready for integration."
}

main "$@"