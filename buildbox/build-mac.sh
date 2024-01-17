#!/bin/sh
set -e
set -x

BUILD_CONFIGURATION=$1

PWDPATH=$PWD

CPPATH="../../../../../build-${BUILD_CONFIGURATION}"
PROJECT="${CPPATH}/telegrammacos"


rsync -av --progress ../telegrammacos $CPPATH

cd $PROJECT

sh "scripts/configure_frameworks.sh"

cp "configurations/${BUILD_CONFIGURATION}.xcconfig" "Telegram-Mac/Release.xcconfig"

# xcodebuild archive -workspace "Telegram-Mac.xcworkspace" \
# -scheme Release \
# -configuration Release \
# -archivePath ../build-${BUILD_CONFIGURATION}

archive="../build-${BUILD_CONFIGURATION}.archive"

cp "${archive}/Products/Applications/Telegram.app" ./Telegram.app
cp "${archive}/dSYMs/Telegram.app.dSYM" ./Telegram.app.dSYM


zip ./Telegram.app ./Telegram.app.zip