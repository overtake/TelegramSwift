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



cp -R "${archive}/Products/Applications/Telegram.app" ../Telegram.app
cp -R "${archive}/dSYMs/Telegram.app.dSYM" ../Telegram.app.dSYM


plist_path="${archive}/Info.plist"

# Extract CFBundleShortVersionString
shortVersion=$(/usr/libexec/PlistBuddy -c "Print ApplicationProperties:CFBundleShortVersionString" "$plist_path")
bundleVersion=$(/usr/libexec/PlistBuddy -c "Print ApplicationProperties:CFBundleVersion" "$plist_path")

appname="Telegram-${shortVersion}-${bundleVersion}.app"

zip ../${appname}.zip ../Telegram.app
zip ../${appname}.DSYM.zip ../Telegram.app.dSYM
