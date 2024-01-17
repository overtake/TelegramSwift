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

xcodebuild archive -workspace "Telegram-Mac.xcworkspace" \
-scheme Release \
-configuration Release \
-archivePath ../build-${BUILD_CONFIGURATION}



cd ..

archive="./build-${BUILD_CONFIGURATION}.xcarchive"

rm -r $(ls -A | grep -v telegrammacos)


appname="Telegram.app"


cp -R "${archive}/Products/Applications/Telegram.app" ${appname}
cp -R "${archive}/dSYMs/Telegram.app.dSYM" ${appname}.dSYM


ditto -c -k --sequesterRsrc --keepParent ${appname}.dSYM ${appname}.DSYM.zip