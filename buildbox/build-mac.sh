#!/bin/sh
set -e
set -x

BUILD_CONFIGURATION=$1

PWDPATH=$PWD

CPPATH="../../../../../build-${BUILD_CONFIGURATION}"
PROJECT="${CPPATH}/telegrammacos"


rsync -av --progress ../telegrammacos $CPPATH

cd $PROJECT
cd ..
rm -r $(ls -A | grep -v telegrammacos)
cd $PROJECT


sh "scripts/configure_frameworks.sh"
cp "configurations/${BUILD_CONFIGURATION}.xcconfig" "Telegram-Mac/Release.xcconfig"
xcodebuild archive -workspace "Telegram-Mac.xcworkspace" \
-scheme Release \
-configuration Release \
-archivePath ${PWDPATH}/../build-${BUILD_CONFIGURATION} &1 | grep -E "(\^error|\^fatal)"


archive="./build-${BUILD_CONFIGURATION}.xcarchive"



appname="Telegram.app"


cp -R "${archive}/Products/Applications/Telegram.app" ${appname}
cp -R "${archive}/dSYMs/Telegram.app.dSYM" ${appname}.dSYM


ditto -c -k --sequesterRsrc --keepParent ${appname}.dSYM ${appname}.DSYM.zip