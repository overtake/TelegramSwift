## Telegram

[**Telegram**](https://telegram.org) is a messaging app with a focus on speed and security. It’s superfast, simple, and free!  This repo contains the official source code for [Telegram for macOS](https://macos.telegram.org/).

#### Screenshots

![Telegram for macOS with a light theme]()

![Telegram for macOS with a dark blue theme]()

![Telegram for macOS with a dark gray theme]()

#### Get it

[![Download on the Mac App Store](https://github.com/overtake/TelegramSwift/blob/master/images/mas_badge.png)](https://itunes.apple.com/us/app/telegram/id747648890?mt=12)

Or you can [download the non-MAS version](https://telegram.org/dl/macos).

## Contributors
### Artwork
* TODO

### Contributors on GitHub
See [this repository’s contributors graph](https://github.com/overtake/TelegramSwift/graphs/contributors).

### Translations
You can help translate Telegram for macOS on [Telegram’s translations platform](https://translations.telegram.org).  Pick your language, then look for the macOS translation set!

### Third Party Libraries
See [LIBRARIES](https://github.com/overtake/TelegramSwift/blob/master/LIBRARIES.md).

## Permissions
Telegram strives to protect your privacy.  This app asks for as few permissions as possible:

* Microphone: You can send voice messages and make audio calls with Telegram.
* Camera: You can set your profile picture using your Mac’s iSight camera.
* Location: You can send your location to friends.
* Outgoing network connections: Telegram needs to connect to the internet to send your messages to your friends.
* Incoming network connections: TODO why?
* User-selected files: You can save files or images to your Mac.
* Downloads folder: Telegram can automatically download files or images you receive.

## License
Telegram for macOS is licensed under the GNU Public License, version 2.0.  See [LICENSE](https://github.com/overtake/TelegramSwift/blob/master/LICENSE.md) for more information.

## Forking
Please fork this application and make something awesome!  Make sure that your fork follows these five requirements:

1. **Do** [get your own API ID](https://core.telegram.org/api/obtaining_api_id).
2. **Don’t** call your fork ‘Telegram’—or at least make sure your users understand that yours is unofficial.
3. **Don’t** use our standard logo (white paper plane in a blue circle) for your fork.
3. **Do** read and follow our [security guidelines](https://core.telegram.org/mtproto/security_guidelines) to make sure you take good care of your users’ data and protect their privacy.
4. **Do** publish your code. The GPL requires it!

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
