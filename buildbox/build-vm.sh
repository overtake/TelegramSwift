#!/bin/sh
set -e
set -x

export PATH="$PATH:$HOME/.fastlane/bin"

BUILD_CONFIGURATION=$1



cd ~/build
cp "configurations/${BUILD_CONFIGURATION}.xcconfig" "Telegram-Mac/Release.xcconfig"
sh scripts/configure_frameworks.sh
         

fastlane Release
tar cf  "./output/Telegram.tar" -C "./output" .



#
#OUTPUT="./output"
#
#mkdir "${OUTPUT}"

#xcrun xcodebuild archive \
#                -workspace Telegram-Mac.xcworkspace \
#                -scheme Release \
#                -configuration Release \
#                -archivePath "${OUTPUT}/Telegram.xcarchive"
       
