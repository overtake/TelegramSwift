[Telegram](https://telegram.org) is a messaging app with a focus on speed and security. It’s superfast, simple and free.
This repo contains the official source code for [Telegram App for MacOS](https://macos.telegram.org).

## Creating your Telegram Application

We welcome all developers to use our API and source code to create applications on our platform.
There are several things we require from **all developers** for the moment.

1. [**Obtain your own api_id**](https://core.telegram.org/api/obtaining_api_id) for your application.
2. Please **do not** use the name Telegram for your app — or make sure your users understand that it is unofficial.
3. Kindly **do not** use our standard logo (white paper plane in a blue circle) as your app's logo.
3. Please study our [**security guidelines**](https://core.telegram.org/mtproto/security_guidelines) and take good care of your users' data and privacy.
4. Please remember to publish **your** code too in order to comply with the licences.

## Usage

1. Clone repo with submodules
```
git clone https://github.com/overtake/TelegramSwift.git --recursive
```
2. Open Telegram-Mac.xcworkspace 
3. Create Config.swift file with
```
let API_ID:Int32 = 'api_id'
let API_HASH:String = "api_hash"
let TEST_SERVER:Bool = false
let languagesCategory = "macos"
```
4. build and enjoy



