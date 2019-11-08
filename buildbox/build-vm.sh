#!/bin/sh


export PATH="$PATH:$HOME/.fastlane/bin"

BUILD_CONFIGURATION=$1

cd ~/build
fastlane $BUILD_CONFIGURATION
tar cf  "./output/Telegram.tar" -C "./output" .
