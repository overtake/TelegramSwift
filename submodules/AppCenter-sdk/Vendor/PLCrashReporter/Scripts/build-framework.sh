#!/bin/sh
set -e

# Builds the framework for the specified target.
# Usage: build-framework.sh <target> <sdk>
# Note: it must be run from Xcode's build phase.

# Print only target name and configuration. Mimic Xcode output to make prettify tools happy.
echo "=== BUILD TARGET $1 OF PROJECT ${PROJECT_NAME} WITH CONFIGURATION ${CONFIGURATION} ==="

# OBJROOT must be customized to avoid conflicts with the current process.
if [ "$2" == "maccatalyst" ]; then
    # Mac Catalyst is a special case - "destination" parameter must be used here.
    env -i "PATH=$PATH" xcodebuild \
        SYMROOT="${SYMROOT}" OBJROOT="${BUILT_PRODUCTS_DIR}" PROJECT_TEMP_DIR="${PROJECT_TEMP_DIR}" \
        ONLY_ACTIVE_ARCH=NO \
        -project "${PROJECT_NAME}.xcodeproj" -configuration "${CONFIGURATION}" \
        -scheme "$1" -destination 'platform=macOS,variant=Mac Catalyst'
else
    env -i "PATH=$PATH" xcodebuild \
        SYMROOT="${SYMROOT}" OBJROOT="${BUILT_PRODUCTS_DIR}" PROJECT_TEMP_DIR="${PROJECT_TEMP_DIR}" \
        ONLY_ACTIVE_ARCH=NO \
        -project "${PROJECT_NAME}.xcodeproj" -configuration "${CONFIGURATION}" \
        -target "$1" -sdk "$2"
fi
