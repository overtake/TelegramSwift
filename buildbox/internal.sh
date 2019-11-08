#/bin/sh
#set -x
#set -e

export PATH="$PATH:$PWD/../deploy"
export PATH="$PATH:$HOME/.fastlane/bin"

tag="$1"

sh ./buildbox/build.sh $tag
source deploy-beta.sh ~/build-beta $PWD Telegram.app ~/.credentials/dsa-$tag
