#!/bin/sh
set -e
set -x


BUILD_CONFIGURATION=$1

PWDPATH=$PWD

CPPATH="../../../../../build-${BUILD_CONFIGURATION}"
PROJECT="${CPPATH}/telegrammacos"


rsync -av --progress ../telegrammacos $CPPATH  > /dev/null

cd $PROJECT
cd ..
files_to_remove=$(ls -A | grep -v telegrammacos || true)
if [ -n "$files_to_remove" ]; then
    rm -r $files_to_remove
else
    echo "No files to remove."
fi

rm -r telegrammacos.xcarchive || true

cd telegrammacos


sh "scripts/configure_frameworks.sh"
cp "configurations/${BUILD_CONFIGURATION}.xcconfig" "Telegram-Mac/Release.xcconfig"

xcodebuild -quiet archive -workspace "Telegram-Mac.xcworkspace" \
-scheme Release \
-configuration Release \
-archivePath ./


cd ..

archive="./telegrammacos.xcarchive"
appname="Telegram.app"

cp -R "${archive}/Products/Applications/Telegram.app" ${appname}
cp -R "${archive}/dSYMs/Telegram.app.dSYM" ${appname}.dSYM


ditto -c -k --sequesterRsrc --keepParent ${appname}.dSYM ${appname}.DSYM.zip