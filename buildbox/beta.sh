#/bin/sh
#set -x
#set -e

export PATH="$PATH:$PWD/../deploy"
fastlane beta
source beta.sh ~/build-beta .. Telegram.app dsa-beta
