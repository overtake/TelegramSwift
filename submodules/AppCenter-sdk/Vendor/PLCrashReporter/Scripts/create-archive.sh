#!/bin/sh
set -e

# Creates arcive for publishing. Should be run from build results directory.
# Usage: create-archive.sh <result-name> <list-of-content>

PROJECT_DIR="$(dirname "$0")/.."

# Create temporary directory
TEMP_DIR=$(mktemp -d -t "$1") 
mkdir -p "$TEMP_DIR/$1"

# Copy required files
cp "$PROJECT_DIR/LICENSE" "$TEMP_DIR/$1/LICENSE.txt"
cp -R "../Documentation" "$TEMP_DIR/$1"
(cd "$TEMP_DIR/$1" && ln -sf "Documentation/index.html" "API Documentation.html")
cp -R "${@:2}" "$TEMP_DIR/$1"

# Archive content
rm -f "$TEMP_DIR/$1.zip"
(cd "$TEMP_DIR" && zip -ryq9 "$1.zip" "$1")
mv "$TEMP_DIR/$1.zip" .

# Remove temporary directory
rm -rf "$TEMP_DIR"
