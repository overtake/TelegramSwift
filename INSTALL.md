# How to Build Telegram for macOS

1. Clone this repository with submodules:
	
	```sh
	git clone https://github.com/overtake/TelegramSwift.git --recurse-submodules
	```
2.  ```brew install cmake ninja openssl@1.1 zlib```
3. Open `Telegram-Mac.xcworkspace` in **Xcode 10.3**.  Avoid Xcode 10.11+ because it causes additional errors when building the libraries with optimizations turned on.  
4. Select build target to **Github** and **Run** build.



# If you want to develop a fork

1. Do first and second step above.
2. Change bundle Identifier and team-id. Easiest way is to search all mentions `ru.keepcoder.Telegram` and change it to your own. Team-id you can find on apple developer portal.
3. Obtain your [API ID](https://core.telegram.org/api/obtaining_api_id). **Note:** The built-in `apiId` is highly limited for api usage. **Do not use it** in any circumstances except verify binaries.
4. Open `Telegram-Mac/Config.swift` and repalce `apiId` and `apiHash` from previous step. **Note:** Do not forget to change `teamId` either.
5. Replace or remove `SFEED_URL` and  `APPCENTER_SECRET`  in `*.xcconfig` files. (First uses for in-app updates and second for collecting crashes on [appcenter](https://appcenter.ms))
6. Write new better code.
7. If you still have a questions feel free to open new issue [here](https://github.com/overtake/TelegramSwift/issues/new).
