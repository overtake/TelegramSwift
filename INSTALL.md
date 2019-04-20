# How to Build Telegram for macOS

1. Clone this repository with submodules:
	
	```sh
	git clone https://github.com/overtake/TelegramSwift.git --recurse-submodules
	```
2. Open `Telegram-Mac.xcworkspace` in **Xcode 10**.  Avoid Xcode 10.2 because it causes additional errors when building the libraries with optimizations turned on.  **Warning:** this project is heavy, so if you have an older Mac, you should probably connect your power adapter.
3. Create `Config.swift` following the example below.  Replace `api_id` and `api_hash` with your own [ID and hash](https://my.telegram.org/apps), and `_YOUR_FORK_NAME_` with your fork name:

	```swift
	let API_ID:Int32 = api_id
	let API_HASH:String = "api_hash"
	let TEST_SERVER:Bool = false
	let languagesCategory = "macos"

	var appVersion: String {
		return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") + " _YOUR_FORK_NAME_"
	}
	```
4. Change build target from **Distrubution** to **Telegram**.
5. Change product team and bundle ID in project, as well as `appGroupName` on [line 86 of `AppDelegate.swift`](https://github.com/overtake/TelegramSwift/blob/master/Telegram-Mac/AppDelegate.swift#L86) to your custom name and bundle ID.  This ensures that your container folder will be different from the official application’s, avoiding potential state corruption problems.
6. You're all set up! Click **Run** and start developing.

## Disable Sparkle

The Sparkle auto-updater can overwrite your build by automatically updating to the latest official Telegram version on quit. If you wish to disable this, comment out the contents of `resetUpdater()` function on [lines 403–430 of `ui/updater/AppUpdateViewController.swift`](https://github.com/overtake/TelegramSwift/blob/master/Telegram-Mac/AppUpdateViewController.swift#L403-L430) file.  If you just want to make it update from somewhere else, you can change the HockeyApp URL in project settings.