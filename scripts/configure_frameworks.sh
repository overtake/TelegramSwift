#!/bin/sh
set -e
set -x

declare -a libs=("OpenSSL" "libopus" "libvpx" "mozjpeg" "libwebp" "ffmpeg" "webrtc")
declare -a libname=("OpenSSLEncryption" "libopus" "libvpx" "Mozjpeg" "libwebp" "ffmpeg" "webrtc")

## now loop through the above array
arraylength=${#libs[@]}

for (( i=0; i<${arraylength}; i++ ));
do
    FWNAME=${libname[$i]}
    LIB=${libs[$i]}
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
    BASE_PWD="${SCRIPT_DIR}/../submodules/${LIB}"
    OUTPUT_DIR=$( mktemp -d )

    COMMON_SETUP=" -project ${SCRIPT_DIR}/../core-xprojects/${LIB}/${FWNAME}.xcodeproj -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES "


    DERIVED_DATA_PATH=$( mktemp -d )
    xcrun xcodebuild build \
        $COMMON_SETUP \
        -scheme "${FWNAME}" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -destination 'generic/platform=macOS'

done

