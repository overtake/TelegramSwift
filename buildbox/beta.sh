#/bin/sh
#set -x
#set -e

export PATH="$PATH:$PWD/../deploy"
export PATH="$PATH:$HOME/.fastlane"

fastlane beta
source beta.sh ~/build-beta .. Telegram.app dsa-beta
