#/bin/sh
#set -x
#set -e

export PATH="$PATH:$PWD/../deploy"
export PATH="$PATH:$HOME/.fastlane/bin"
sh ./buildbox/build.sh beta
source deploy-beta.sh ~/build-beta $PWD Telegram.app ~/.credentials/dsa-beta
