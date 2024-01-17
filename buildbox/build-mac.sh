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

xcodebuild archive -workspace "Telegram-Mac.xcworkspace" \
-scheme Release \
-configuration Release \
-archivePath ../ \
-xcconfig "configurations/${BUILD_CONFIGURATION}.xcconfig"


cd $PWDPATH
         
