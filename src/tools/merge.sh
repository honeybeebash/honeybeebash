#!/bin/bash

# merge.sh
# Merges the Job ruleset (.cache/dataset.csv + config/RUN_*) to the global ruleset on this machine
# Usage: tools/merge.sh {BASEDIR} {JOBDIR}

if [[ $1 == "" ]] || [[ $2 == "" ]] || [[ $3 == "" ]] || [[ $4 == "" ]]; then
    echo -e "Syntax: ./merge.sh {configdir} {workspace dir} {jobname:version}"
    exit 1
fi

if [ ! -d $1 ]; then
    echo -e "The basedir '$1' does not exist"
    exit 1
fi

if [ ! -f $1/bee.sh ]; then
    echo -e "The basedir '$1' does not seem valid"
    exit 1
fi

TMP_BASE_DIR="/opt/honeybeebash"
TMP_CONFIG_DIR="$1"
TMP_USER_LOCAL_DIR="$2"

STR="$3"
TMP_JOB_NAME="${STR%%:*}"
TMP_JOB_VERSION="${STR#*:}"
if [[ -z "$TMP_JOB_VERSION" ]]; then
    TMP_JOB_VERSION="default"
fi

TMP_JOB_DIR="$TMP_USER_LOCAL_DIR/workspace/$TMP_JOB_NAME/$TMP_JOB_VERSION"

if [ ! -d "$TMP_JOB_DIR" ]; then
    echo -e "The jobdir for '$TMP_JOB_NAME/$TMP_JOB_VERSION' does not exist"
    exit 1
fi

if [ ! -f "$TMP_JOB_DIR/config/BEE_PROFILE" ]; then
    echo -e "The jobdir for '$TMP_JOB_NAME/$TMP_JOB_VERSION' does not seem valid"
    exit 1
fi

# Combine job dataset with global dataset

if [[ -f "$TMP_JOB_DIR/cache/dataset.csv" ]]; then
    cat "$TMP_JOB_DIR/cache/dataset.csv" >> "$TMP_CONFIG_DIR/default-dataset.csv"
    # Clear origin
    echo -e "command,label,weight\n" > "$TMP_JOB_DIR/cache/dataset.csv"
    # Sort and remove duplicates
    awk '!visited[$0]++' "$TMP_CONFIG_DIR/default-dataset.csv" > "$TMP_CONFIG_DIR/default-dataset.csv.tmp"
    mv -f "$TMP_CONFIG_DIR/default-dataset.csv.tmp" "$TMP_CONFIG_DIR/default-dataset.csv"
    sort -o "$TMP_CONFIG_DIR/default-dataset.csv" "$TMP_CONFIG_DIR/default-dataset.csv"
fi

if [[ -f "$TMP_JOB_DIR/config/RUN_FORBIDDEN" ]]; then
    cat "$TMP_JOB_DIR/config/RUN_FORBIDDEN" >> "$TMP_CONFIG_DIR/RUN_FORBIDDEN"
    truncate -s 0 "$TMP_JOB_DIR/config/RUN_FORBIDDEN"
    sort -u -o "$TMP_BASE_DIR/config/RUN_FORBIDDEN" "$TMP_CONFIG_DIR/RUN_FORBIDDEN"
fi
if [[ -f "$TMP_JOB_DIR/config/RUN_ALWAYS" ]]; then
    cat "$TMP_JOB_DIR/config/RUN_ALWAYS" >> "$TMP_CONFIG_DIR/RUN_ALWAYS"
    truncate -s 0 "$TMP_JOB_DIR/config/RUN_ALWAYS"
    sort -u -o "$TMP_BASE_DIR/config/RUN_ALWAYS" "$TMP_CONFIG_DIR/RUN_ALWAYS"
fi
if [[ -f "$TMP_JOB_DIR/config/RUN_NEVER" ]]; then
    cat "$TMP_JOB_DIR/config/RUN_NEVER" >> "$TMP_CONFIG_DIR/RUN_NEVER"
    truncate -s 0 "$TMP_JOB_DIR/config/RUN_NEVER"
    sort -u -o "$TMP_BASE_DIR/config/RUN_NEVER" "$TMP_CONFIG_DIR/RUN_NEVER"
fi
if [[ -f "$TMP_JOB_DIR/config/RUN_REPLACE" ]]; then
    cat "$TMP_JOB_DIR/config/RUN_REPLACE" >> "$TMP_CONFIG_DIR/RUN_REPLACE"
    truncate -s 0 "$TMP_JOB_DIR/config/RUN_REPLACE"
    sort -u -o "$TMP_BASE_DIR/config/RUN_REPLACE" "$TMP_CONFIG_DIR/RUN_REPLACE"
fi

echo "Done"
exit 0
