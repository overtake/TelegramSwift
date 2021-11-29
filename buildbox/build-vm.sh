#!/bin/sh


export PATH="$PATH:$HOME/.fastlane/bin"

BUILD_CONFIGURATION=$1

cd ~/build
cp "configurations/${BUILD_CONFIGURATION}.xcconfig" "Telegram-Mac/${BUILD_CONFIGURATION}.xcconfig"
sh scripts/configure_frameworks.sh
xcodebuild -workspace Telegram-Mac.xcworkspace -scheme Release -configuration Release
tar cf  "./output/Telegram.tar" -C "./output" .
