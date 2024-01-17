#!/bin/sh
set -e
set -x

BUILD_CONFIGURATION=$1

sh scripts/configure_frameworks.sh

xcodebuild archive -workspace Telegram-Mac.xcworkspace \
-scheme Release \
-configuration Release \
-archivePath ../../../../build-${BUILD_CONFIGURATION} \
-xcconfig "configurations/${BUILD_CONFIGURATION}.xcconfig"

         
