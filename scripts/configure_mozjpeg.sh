#!/bin/sh
set -e
set -x


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BASE_PWD="${SCRIPT_DIR}/../submodules/Mozjpeg"
FWNAME="Mozjpeg"
OUTPUT_DIR=$( mktemp -d )

COMMON_SETUP=" -project ${SCRIPT_DIR}/../core-xprojects/Mozjpeg/${FWNAME}.xcodeproj -configuration Release -quiet BUILD_LIBRARY_FOR_DISTRIBUTION=YES "


DERIVED_DATA_PATH=$( mktemp -d )
xcrun xcodebuild build \
    $COMMON_SETUP \
    -scheme "${FWNAME}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'generic/platform=macOS'


mkdir -p "${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}/${FWNAME}.framework"
ditto "${DERIVED_DATA_PATH}/Build/Products/Release/${FWNAME}.framework" "${OUTPUT_DIR}/${FWNAME}.framework"
rm -rf "${DERIVED_DATA_PATH}"



rm -rf "${BASE_PWD}/Frameworks"
mkdir -p "${BASE_PWD}/Frameworks"

xcrun xcodebuild -quiet -create-xcframework \
    -framework "${OUTPUT_DIR}/${FWNAME}.framework" \
    -output "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

