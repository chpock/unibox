#!/bin/sh

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
EXAMPLES_DIR="$SELF_DIR/examples"
CHART_DIR="$SELF_DIR/charts/unibox"
GOLDEN_DIR="$SELF_DIR/tests"

SAVE=0

if [ "$1" = "save" ]; then
    SAVE=1
    echo
    echo "Mode: save test results"
elif [ -n "$1" ]; then
    echo
    echo "Unknown arg: '$1'"
    echo
    echo "Usage: $0 [save]"
    exit 1
fi

set -e

#WORKING_DIR="$(mktmp -d)"
WORKING_DIR="/tmp/unibox.test"; rm -rf "$WORKING_DIR" && mkdir -p "$WORKING_DIR"

RC=0

for TEST_CASE_FILE in "$EXAMPLES_DIR"/*.yaml; do
    echo
    echo "--------------------------------------------------"
    echo "Case: $TEST_CASE_FILE"
    echo "--------------------------------------------------"
    TEST_CASE="${TEST_CASE_FILE##*/}"
    TEST_CASE="${TEST_CASE%.*}"
    # run in subshell to avoid PWD change
    set +e; ( set -e
        RC=0
        GOLDEN_DIR="$GOLDEN_DIR/$TEST_CASE"
        cd "$CHART_DIR"
        helm template . -f "$TEST_CASE_FILE" > "$WORKING_DIR"/all.yaml
        cd "$WORKING_DIR"
        TRAILING_SPACES="$(awk '{if ($0 ~ /[[:space:]]$/) print "  " NR ": " $0 "|"}' all.yaml)"
        if [ -n "$TRAILING_SPACES" ]; then
            echo
            echo "ERROR: found lines with trailing spaces:"
            echo "$TRAILING_SPACES"
            RC=1
        fi
        awk 'BEGIN {n=-1} /---/ {n++; next} {print > "document_" n ".yaml"}' all.yaml
        rm -f all.yaml
        for DOCUMENT_FILE in document_*.yaml; do
            KIND="$(yq '.kind | downcase' "$DOCUMENT_FILE")"
            NAME="$(yq '.metadata.name' "$DOCUMENT_FILE")"
            NORM_DOCUMENT_FILE="${KIND}-${NAME}.yaml"
            yq 'sort_keys(..)' "$DOCUMENT_FILE" > "$NORM_DOCUMENT_FILE"
            rm -f "$DOCUMENT_FILE"
        done
        if [ $SAVE -eq 1 ]; then
            echo
            echo "Save test results..."
            rm -rf "$GOLDEN_DIR" && mkdir -p "$GOLDEN_DIR"
            cp -v * "$GOLDEN_DIR"
        elif [ ! -d "$GOLDEN_DIR" ]; then
            echo
            echo "WARNING: test result directory doesn't exist: $GOLDEN_DIR"
        elif ! diff -r . "$GOLDEN_DIR" >/dev/null; then
            echo
            echo "ERROR: found differences:"
            diff --color=auto -rubBaN . "$GOLDEN_DIR"
            RC=1
        fi
        exit $RC
    ); LOCAL_RC=$?; set -e
    RC=$(( RC + LOCAL_RC ))
done

[ $RC -eq 0 ] || { echo; echo "Exit code: $RC"; }
exit $RC