#!/bin/sh
set -e
set -x

declare -a libs=("OpenSSL" "libopus" "libvpx" "mozjpeg" "libwebp" "ffmpeg" "webrtc")
declare -a libname=("OpenSSLEncryption" "libopus" "libvpx" "Mozjpeg" "libwebp" "ffmpeg" "webrtc")

arraylength=${#libs[@]}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

RebuildFile="${SCRIPT_DIR}/rebuild"

if grep -q yes "$RebuildFile"; then
for (( i=0; i<${arraylength}; i++ ));
do
    FWNAME=${libname[$i]}
    LIB=${libs[$i]}
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
    BASE_PWD="${SCRIPT_DIR}/../submodules/${LIB}"
    OUTPUT_DIR=$( mktemp -d )

    COMMON_SETUP="${SCRIPT_DIR}/../core-xprojects/${LIB}/build"
    rm -rf $COMMON_SETUP


done
fi



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

