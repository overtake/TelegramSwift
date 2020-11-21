#!/bin/bash
set -e

# Combines frameworks for device and simulator into universal one.
# Usage: combine-frameworks.sh <device> <simulator> <output>

echo "Combining device and simulator frameworks"
cp -Rv "$1" "$3"

# Combining libraries.
product_name=${1##*/}
product_name=${product_name%.*}
$(dirname "$0")/combine-libraries.sh \
    "$1/${product_name}" \
    "$2/${product_name}" \
    "$3/${product_name}"

echo "Appending simulator platform to Info.plist"
simulator_platform=$(plutil -extract CFBundleSupportedPlatforms.0 xml1 "$2/Info.plist" -o -| sed -n "s/.*<string>\(.*\)<\/string>.*/\1/p")
plutil -insert CFBundleSupportedPlatforms.1 -string $simulator_platform "$3/Info.plist"
