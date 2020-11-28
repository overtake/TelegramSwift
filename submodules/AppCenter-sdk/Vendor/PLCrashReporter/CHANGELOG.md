# PLCrashReporter Change Log

## Version 1.8.1

* Re-build Apple Silicon binaries with [Xcode 12.2 Release Candidate](https://developer.apple.com/news/releases/?id=11052020h) to [be able to](https://developer.apple.com/news/releases/?id=11052020i) submit the applications that use the framework as a binary to the App Store.

___

## Version 1.8.0

* Drop support of old versions of iOS and macOS. The minimal version is iOS 9 and macOS 10.9 now.
* Add Apple Silicon support. Note that `arm64` for iOS and tvOS simulators is available only in xcframework or SwiftPM.
* Support saving custom data in crash report, see `PLCrashReporter.customData` property.
* Fix exported symbols list for applying `PLCRASHREPORTER_PREFIX` prefix.
* Fix Xcode 12 compatibility if the framework is used from sources.
* Fix getting the subtype of device architecture on iOS 14.
* Fix crash on collecting register values on `arm64e` devices with iOS 14.

___

## Version 1.7.2

* Fix building on Xcode 12 beta.
* Use memory mapping to reduce live reports memory pressure.
* Remove "CrashReporter Key: TODO" from text report output.
* Add `[PLCrashReporter]` prefix for all log messages.

___

## Version 1.7.1

* Fix crash on old operating systems: macOS 10.11, iOS 9 and tvOS 9 (and older).
* Fix duplicate symbols in applications with `-all_load` linker flag.
* Fix exporting PLCrashReporter along with an application into `.xcarchive`.
* Fix collecting stacktraces on `arm64e` devices in some cases.

___

## Version 1.7.0

* Drop support old versions of Xcode. The minimal version is Xcode 11 now.
* Support [Mac Catalyst](https://developer.apple.com/mac-catalyst/).
* Distribute `.xcframework` archive alongside with the other options.
* Improve reliability of saving crash reports in case of memory corruption.
* Fix symbolication issues with new Objective-C runtime version.
* Add workaround for SwiftPM on Xcode 11.1 bug (`SWIFT_PACKAGE` is not defined) that prevents library usage on macOS.

___

## Version 1.6.0

* Support integration via [Carthage](https://github.com/Carthage/Carthage).
* Support integration via [Swift Package Manager](https://swift.org/package-manager). Please note that this way has some limitations:
  * macOS 64-bit mach_* APIs is not available here.
  * `protobuf-c` symbols are not prefixed, so it can cause conflicts with other libraries.
  * Additional architectures like `arm64e` are not built explicitly.
* Migrate to Automatic Reference Counting (ARC).
* Embed required `protoc-c` sources instead of using submodule. No more additional steps on cloning the repo.
* Store sources generated from `*.proto` files to drop `protobuf-c` compiler requirement for building the library. It's required only for contributors now.
* Enable generating debug symbols for static libraries. Previously it was included only to macOS framework.
* Fix framework targets type issue that prevents use the library as a project dependency (instead of binary distribution) in Xcode 11.
* Fix implicit casting warnings.

___

## Version 1.5.1

* Fix support for Xcode 10.

___

## Version 1.5.0

* Drop support old versions of Xcode and iOS. The minimal versions are Xcode 10 and iOS 8 now.
* Remove `UIKit` dependency on iOS.
* Fix arm64e crash report text formatting.
* Fix possible crash `plcrash_log_writer_set_exception` method when `NSException` instances have a `nil` reason.
* Apply bit mask for non-pointer isa values on macOS x64 (used in runtime symbolication).
* Strip pointer authentication codes on arm64e.

___

## Version 1.4.0

* Support macOS 10.15 and XCode 11 and drop support for macOS 10.6.
* Add support for tvOS apps.
* Update `protobuf-c` to version 1.3.2. `protoc-c` code generator binary has been removed from the repo, so it should be installed separately now (`brew install protobuf-c`). `protoc-c` C library is included as a git submodule, please make sure that it's initialized after update (`git submodule update --init`).
* Remove outdated "Google Toolbox for Mac" dependency.
* The sources aren't distributed in the release archive anymore. Please use GitHub snapshot instead.
* Distribute static libraries in a second archive aside the frameworks archive.
* Fix minor bugs in runtime symbolication: use correct bit-mask for the data pointer and correctly reset error code if no categories for currently symbolicating class.
* Add preview support for the arm64e CPU architecture.
* Support for arm64e devices that run an arm64 slice (which is the default for apps that were compiled with Xcode 10 or earlier).
* Remove support for armv6 CPU architecture as it is no longer supported.
* Improve namespacing to avoid symbol collisions when integrating PLCrashReporter.
* Fix a crash that occurred on macOS where PLCrashReporter would be caught in an endless loop handling signals.
* Make it possible to not add an uncaught exception handler via `shouldRegisterUncaughtExceptionHandler` property on `PLCrashReporterConfig`. This scenario is important when using PLCrashReporter inside managed runtimes, i.e. for a Xamarin app. This is not a breaking change and behavior will not change if you use PLCrashReporter.
