#!/bin/bash

# forget.sh
# Removes a dataset rule  from cache/dataset.csv
# Usage: tools/forget.sh {JOBDIR:VERSION} {COMMAND} 

if [[ $1 == "" ]] || [[ $2 == "" ]]; then
    echo -e "Syntax: ./forget.sh {jobname:version} {command}"
    exit 1
fi

# --- Paths ---
BASE_DIR="/opt/honeybeebash"

# --- User specific paths ---
USER_CONFIG_DIR="$HOME/.config/honeybeebash"
USER_LOCAL_DIR="$HOME/.local/share/honeybeebash"

# --- Split job and version ---
STR="$1"
TMP_JOB_NAME="${STR%%:*}"
TMP_JOB_VERSION="${STR#*:}"
if [[ -z "$TMP_JOB_VERSION" ]]; then
    TMP_JOB_VERSION="default"
fi

TARGET_CMD="$2"

# Configuration
TMP_JOB_DIR="$USER_LOCAL_DIR/workspace/$TMP_JOB_NAME/$TMP_JOB_VERSION"

# Colors for the HUD
RED='\033[0;31m'
GREEN='\033[0;32m'
GOLD='\033[0;33m'
NC='\033[0m'

if [ -z "$TARGET_CMD" ]; then
    echo -e "${RED}⚠ Error: No command string provided.${NC}"
    echo "Usage: ./forget.sh \"command string\""
    exit 1
fi

echo -e "${GOLD}Honeybee is unlearning:${NC} $TARGET_CMD"


# Function: remove_line_from_file
# Usage: remove_line_from_file "string_to_find" "path/to/file"
remove_line_from_file() {
    local SEARCH_STR="$1"
    local TARGET_FILE="$2"

    if [ -f "$TARGET_FILE" ]; then
        # Create a temp file, grep out the line, then overwrite the original
        grep -vF "$SEARCH_STR" "$TARGET_FILE" > "$TARGET_FILE.tmp" && mv "$TARGET_FILE.tmp" "$TARGET_FILE"
        return 0
    else
        return 1 # File didn't exist
    fi
}

# Function: remove_replace_rule
# Usage: remove_replace_rule "COMMAND" "path/to/RUN_REPLACE"
remove_replace_rule() {
    local SEARCH_CMD="$1"
    local TARGET_FILE="$2"

    if [ -f "$TARGET_FILE" ]; then
        # Matches the string at the start of the line followed by a colon
        # Uses double quotes in the pattern to handle variable expansion safely
        grep -v "^\"$SEARCH_CMD\":" "$TARGET_FILE" > "$TARGET_FILE.tmp" && mv "$TARGET_FILE.tmp" "$TARGET_FILE"
        return 0
    else
        return 1
    fi
}

# Remove the target command
remove_line_from_file "$TARGET_CMD" "$TMP_JOB_DIR/cache/dataset.csv"
remove_line_from_file "$TARGET_CMD" "$TMP_JOB_DIR/config/RUN_NEVER"
remove_line_from_file "$TARGET_CMD" "$TMP_JOB_DIR/config/RUN_ALWAYS"




