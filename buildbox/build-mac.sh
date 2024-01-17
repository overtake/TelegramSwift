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

archive="../build-${BUILD_CONFIGURATION}.xcarchive"


plist_path="${archive}/Info.plist"

shortVersion=$(/usr/libexec/PlistBuddy -c "Print ApplicationProperties:CFBundleShortVersionString" "$plist_path")
bundleVersion=$(/usr/libexec/PlistBuddy -c "Print ApplicationProperties:CFBundleVersion" "$plist_path")

appname="Telegram-${shortVersion}.${bundleVersion}.app"


cp -R "${archive}/Products/Applications/Telegram.app" ../${appname}.app
cp -R "${archive}/dSYMs/Telegram.app.dSYM" ../${appname}.dSYM


zip ../${appname}.zip ../${appname}.app/
zip ../${appname}.DSYM.zip ../${appname}.app.dSYM/
