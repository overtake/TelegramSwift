#/bin/sh
set -x
set -e

export PATH="$PATH:$PWD/../deploy"
export PATH="$PATH:$HOME/.fastlane/bin"

source "../deploy/keychain.sh" .

xcrun notarytool store-credentials "Telegram" --apple-id "appstore@telegram.org" --team-id 6N38VWS5BX --password tfmu-iwxg-xqth-iqvh

 xcrun notarytool submit '/Users/overtake/build-Stable/Telegram-10.2.254873.app.zip' --keychain-profile "Telegram" --wait

#xcrun notarytool store-credentials $notarytool_keychain_profile --apple-id "${app_store_id}" --team-id "${app_team_id}" --password "${app_store_password}"
#
#xcrun notarytool submit "$BUILD_PATH/$ZIP_NAME" --keychain-profile $notarytool_keychain_profile --wait
#
#tag="$1"
#sh ./buildbox/cleanup-telegram-build-vms.sh
#sh ./buildbox/build.sh $tag
#sh deploy-$tag.sh ~/build-$tag $PWD Telegram.app ~/.credentials/dsa-$tag
#rm -rf ~/build-$tag
