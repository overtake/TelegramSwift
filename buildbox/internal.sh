#/bin/sh
set -x
set -e

export PATH="$PATH:$PWD/../deploy"
export PATH="$PATH:$HOME/.fastlane/bin"
export PATH="$PATH:/opt/homebrew/bin"



tag="$1"
sh ./buildbox/build-mac.sh $tag
sh deploy-$tag.sh ~/build-$tag $PWD Telegram.app ~/.credentials/dsa-$tag
