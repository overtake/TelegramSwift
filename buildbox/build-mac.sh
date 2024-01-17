#!/bin/sh
set -e
set -x

BUILD_CONFIGURATION=$1

CPPATH="../../../../../build-${BUILD_CONFIGURATION}"
PROJECT="{$CPPATH}/telegrammacos"

rsync -av --progress ../telegrammacos $CPPATH

sh "{$PROJECT}/scripts/configure_frameworks.sh"

xcodebuild archive -workspace "{$PROJECT}/Telegram-Mac.xcworkspace" \
-scheme Release \
-configuration Release \
-archivePath $CPPATH \
-xcconfig "{$PROJECT}/configurations/${BUILD_CONFIGURATION}.xcconfig"

         
