#!/bin/sh


export PATH="$PATH:$HOME/.fastlane/bin"

BUILD_CONFIGURATION=$1

cd ~/build
sh scripts/configure_frameworks.sh
export FASTLANE_XCODE_LIST_TIMEOUT=120
fastlane $BUILD_CONFIGURATION
tar cf  "./output/Telegram.tar" -C "./output" .
