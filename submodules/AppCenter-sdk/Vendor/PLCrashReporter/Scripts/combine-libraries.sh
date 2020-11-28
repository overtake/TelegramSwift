#!/bin/bash
set -e

# Combines libraries for device and simulator into universal one.
# Usage: combine-libraries.sh <device> <simulator> <output>

library_archs_diff() {
  local device_archs=($(lipo -archs "$1"))
  local simulator_archs=($(lipo -archs "$2"))
  comm -12 <(printf '%s\n' "${device_archs[@]}" | sort) <(printf '%s\n' "${simulator_archs[@]}" | sort)
}
duplicate_archs=($(library_archs_diff "$1" "$2"))
if [ ${#duplicate_archs[@]} -ne 0 ]; then
  echo "Removing duplicate architectures (${duplicate_archs[@]}) from library for simulator"
  lipo "$2" ${duplicate_archs[@]/#/ -remove } -output "$3"
elif [ "$2" != "$3" ]; then
  cp "$2" "$3"
fi

echo "Combining device and simulator libraries"
lipo "$1" "$3" -create -output "$3"

# Show information of result library.
lipo -info "$3"
