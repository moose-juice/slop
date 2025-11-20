#!/bin/zsh

set -euo pipefail

BASE_URL="$1"     # e.g. https://example.com/releases/
FILE_BASE="$2"    # e.g. "myapp-macos-arm64"
TMPDIR=$(mktemp -d)
echo "Using temp directory: $TMPDIR"

# ---- STEP 1: Fetch index page ----------------------------------------------

HTML=$(curl -sSL "$BASE_URL")

# Extract lines with version links and timestamps
# Example line:
# <a href="1.1.11/">1.1.11/</a>    12-Nov-2025 10:24 -
INDEX_LINES=$(echo "$HTML" | grep -E '<a href="([0-9]+\.)+[0-9]+/">' )

if [[ -z "$INDEX_LINES" ]]; then
    echo "No versions found at $BASE_URL"
    exit 1
fi

# ---- STEP 2: Parse version + timestamp pairs -------------------------------

# We will build an array of lines like:
# "1.1.11|12-Nov-2025 10:24"
VERSION_LIST=()

while IFS= read -r line; do
    version=$(echo "$line" | sed -n 's/.*href="\([0-9.]\+\)\/".*/\1/p')
    timestamp=$(echo "$line" | sed -n 's/.*<\/a>[[:space:]]*\([^<]\+\)-/\1/p' | xargs)

    if [[ -n "$version" && -n "$timestamp" ]]; then
        VERSION_LIST+=("${version}|${timestamp}")
    fi
done <<< "$INDEX_LINES"

# ---- STEP 3: Find the latest timestamp -------------------------------------

LATEST_VERSION=""
LATEST_TS_EPOCH=0

for item in "${VERSION_LIST[@]}"; do
    ver="${item%%|*}"
    ts="${item#*|}"

    # Convert timestamp to epoch
    epoch=$(date -j -f "%d-%b-%Y %H:%M" "$ts" "+%s" 2>/dev/null)

    if [[ -n "$epoch" && "$epoch" -gt "$LATEST_TS_EPOCH" ]]; then
        LATEST_TS_EPOCH="$epoch"
        LATEST_VERSION="$ver"
    fi
done

if [[ -z "$LATEST_VERSION" ]]; then
    echo "Could not determine latest version."
    exit 1
fi

echo "Latest version based on timestamp: $LATEST_VERSION"

LATEST_URL="${BASE_URL%/}/$LATEST_VERSION/"

# ---- STEP 4: Fetch latest version directory --------------------------------

VERSION_HTML=$(curl -sSL "$LATEST_URL")

# Extract all files from directory listing
FILE_LINES=$(echo "$VERSION_HTML" | grep -E '<a href=')

# ---- STEP 5: Find file that matches basename -------------------------------

FILE_URL=""
while IFS= read -r line; do
    fname=$(echo "$line" | sed -n 's/.*href="\([^"]\+\)".*/\1/p')

    # Skip subdirectories
    if [[ "$fname" == */ ]]; then
        continue
    fi

    if [[ "$fname" == ${FILE_BASE}* ]]; then
        FILE_URL="${LATEST_URL}${fname}"
        break
    fi
done <<< "$FILE_LINES"

if [[ -z "$FILE_URL" ]]; then
    echo "No file found matching basename: $FILE_BASE"
    exit 1
fi

echo "Downloading: $FILE_URL"

curl -sSL -o "$TMPDIR/$FILE_BASE" "$FILE_URL"

echo "Saved file to: $TMPDIR/$FILE_BASE"