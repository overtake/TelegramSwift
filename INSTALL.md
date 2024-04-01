# How to Build Telegram for macOS

1. Clone this repository with submodules:
	```
	git clone https://github.com/overtake/TelegramSwift.git --recurse-submodules
	```
2. Install Homebrew:
	```
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	```
3. Install tools: 
	```
	brew install cmake ninja openssl@1.1 zlib autoconf libtool automake yasm pkg-config
 	```
4. Update ./scripts/rebuild file 
	```
	replace "no" to "yes"
	```
5. Run scripts to configurate framework: 
	```
	sh %project_dir%/scripts/configure_frameworks.sh
	```

6. Open `Telegram-Mac.xcworkspace` in [the latest Xcode](https://apps.apple.com/us/app/xcode/id497799835).  
7. Setup codesign and **Build**!



# If you want to develop a fork

1. For starters, you need [to build application](https://github.com/overtake/TelegramSwift/blob/master/INSTALL.md#how-to-build-telegram-for-macos).
2. Change bundle Identifier and team-id. Easiest way is to search all mentions `ru.keepcoder.Telegram` and change it to your own. Team-id you can find on apple developer portal.
3. Obtain your [API ID](https://core.telegram.org/api/obtaining_api_id). **Note:** The built-in `apiId` is highly limited for api usage. **Do not use it** in any circumstances except verify binaries.
4. Open `Telegram-Mac/Config.swift` and repalce `apiId` and `apiHash` from previous step. **Note:** Do not forget to change `teamId` either.
5. Replace or remove `SFEED_URL` and  `APPCENTER_SECRET`  in `*.xcconfig` files. (First uses for in-app updates and second for collecting crashes on [appcenter](https://appcenter.ms))
6. Write new better code.
7. If you still have a questions feel free to open new issue [here](https://github.com/overtake/TelegramSwift/issues/new).
