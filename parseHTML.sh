#!/bin/zsh
#
# Placeholder script demonstrating the versioned file downloader function
# Includes:
#   - download_latest_versioned_file()
#   - dummy log() function (replace with real one)
#   - example caller
#

set -euo pipefail

##############################################################################
# Placeholder log() function
# Replace this with your real log() implementation
##############################################################################
log() {
    local level="$1"
    local msg="$2"
    printf "[%s] %s\n" "$level" "$msg"
}

##############################################################################
# download_latest_versioned_file()
# Fetches index → finds latest version → downloads matching file
# Returns:
#   - On success: prints the full path to the downloaded file
#   - On failure: returns specific exit codes (10–41)
##############################################################################
download_latest_versioned_file() {
    local BASE_URL="$1"
    local FILE_BASE="$2"
    local TMPDIR
    TMPDIR=$(mktemp -d)

    local http_code HTML

    ###########################################################################
    # 1. FETCH BASE URL
    ###########################################################################
    HTML=$(curl -sS -w "%{http_code}" -o "$TMPDIR/index.html" "$BASE_URL")
    http_code="$HTML"

    if [[ "$http_code" == "000" ]]; then
        log "ERROR" "NETWORK ERROR: Could not reach $BASE_URL (exit 10)"
        return 10
    fi

    if [[ "$http_code" != 2* ]]; then
        log "ERROR" "HTTP error fetching $BASE_URL (HTTP $http_code, exit 11)"
        return 11
    fi

    HTML=$(cat "$TMPDIR/index.html")
    if [[ -z "$HTML" ]]; then
        log "ERROR" "Empty response from $BASE_URL (exit 12)"
        return 12
    fi

    ###########################################################################
    # 2. PARSE VERSION DIRECTORIES
    ###########################################################################
    local INDEX_LINES
    INDEX_LINES=$(echo "$HTML" | grep -E '<a href="([0-9]+\.)+[0-9]+/">' )

    if [[ -z "$INDEX_LINES" ]]; then
        log "ERROR" "No version directories found at $BASE_URL (exit 20)"
        return 20
    fi

    local VERSION_LIST=()
    local line version timestamp

    while IFS= read -r line; do
        version=$(echo "$line" | sed -E 's/.*href="([0-9.]+)\/".*/\1/')
        timestamp=$(echo "$line" | sed -E 's#.*</a>[[:space:]]*([^<]+)-.*#\1#' | xargs)
        [[ -n "$version" && -n "$timestamp" ]] && VERSION_LIST+=("${version}|${timestamp}")
    done <<< "$INDEX_LINES"

    ###########################################################################
    # 3. DETERMINE LATEST VERSION
    ###########################################################################
    local LATEST_VERSION=""
    local LATEST_TS_EPOCH=0
    local item ver ts epoch

    for item in "${VERSION_LIST[@]}"; do
        ver="${item%%|*}"
        ts="${item#*|}"
        epoch=$(date -j -f "%d-%b-%Y %H:%M" "$ts" "+%s" 2>/dev/null || echo "")

        [[ -z "$epoch" ]] && continue

        if (( epoch > LATEST_TS_EPOCH )); then
            LATEST_TS_EPOCH="$epoch"
            LATEST_VERSION="$ver"
        fi
    done

    if [[ -z "$LATEST_VERSION" ]]; then
        log "ERROR" "Could not determine latest version (exit 21)"
        return 21
    fi

    local LATEST_URL="${BASE_URL%/}/$LATEST_VERSION/"

    ###########################################################################
    # 4. FETCH VERSION DIRECTORY
    ###########################################################################
    local VERSION_HTML
    VERSION_HTML=$(curl -sS -w "%{http_code}" -o "$TMPDIR/version.html" "$LATEST_URL")
    http_code="$VERSION_HTML"

    if [[ "$http_code" == "000" ]]; then
        log "ERROR" "NETWORK ERROR: Could not reach $LATEST_URL (exit 10)"
        return 10
    fi

    if [[ "$http_code" != 2* ]]; then
        log "ERROR" "HTTP error fetching $LATEST_URL (HTTP $http_code, exit 30)"
        return 30
    fi

    VERSION_HTML=$(cat "$TMPDIR/version.html")

    ###########################################################################
    # 5. LOCATE FILE MATCHING PREFIX
    ###########################################################################
    local FILE_LINES fname FILE_URL
    FILE_LINES=$(echo "$VERSION_HTML" | grep -E '<a href=')

    while IFS= read -r line; do
        fname=$(echo "$line" | sed -E 's/.*href="([^"]+)".*/\1/')
        [[ "$fname" == */ ]] && continue
        if [[ "$fname" == ${FILE_BASE}* ]]; then
            FILE_URL="${LATEST_URL}${fname}"
            break
        fi
    done <<< "$FILE_LINES"

    if [[ -z "$FILE_URL" ]]; then
        log "ERROR" "File matching prefix '$FILE_BASE' not found (exit 31)"
        return 31
    fi

    ###########################################################################
    # 6. DOWNLOAD FILE
    ###########################################################################
    local FILE_CODE
    (
        cd "$TMPDIR"
        FILE_CODE=$(curl -sS -w "%{http_code}" -O --remote-header-name "$FILE_URL")
    )

    if [[ "$FILE_CODE" == "000" ]]; then
        log "ERROR" "NETWORK ERROR downloading file: $FILE_URL (exit 10)"
        return 10
    fi

    if [[ "$FILE_CODE" != 2* ]]; then
        log "ERROR" "HTTP error downloading $FILE_URL (HTTP $FILE_CODE, exit 40)"
        return 40
    fi

    ###########################################################################
    # 7. VERIFY DOWNLOADED FILE EXISTS
    ###########################################################################
    local DOWNLOADED_FILE
    DOWNLOADED_FILE=$(find "$TMPDIR" -type f -maxdepth 1 | head -1)

    if [[ -z "$DOWNLOADED_FILE" ]]; then
        log "ERROR" "File downloaded but missing in TMPDIR (exit 41)"
        return 41
    fi

    echo "$DOWNLOADED_FILE"
    return 0
}

##############################################################################
# MAIN — Example Caller
##############################################################################
main() {
    log "INFO" "Starting placeholder script..."

    # Example values (replace with real logic)
    BASE_URL="https://example.com/releases/"
    FILE_PREFIX="myapp-macos-arm64"

    log "INFO" "Looking for latest version under $BASE_URL"
    log "INFO" "Searching for file starting with prefix: $FILE_PREFIX"

    downloaded_file=$(download_latest_versioned_file "$BASE_URL" "$FILE_PREFIX")
    rc=$?

    if (( rc != 0 )); then
        log "ERROR" "Download failed (exit code $rc)"
        exit $rc
    fi

    log "INFO" "Downloaded file: $downloaded_file"
    log "INFO" "Placeholder script completed successfully."
}

main "$@"