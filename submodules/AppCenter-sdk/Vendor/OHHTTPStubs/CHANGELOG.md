# OHHTTPStubs — CHANGELOG

## Master

* Added `hasFormBody(_:)` matcher.  
[@417-72KI](https://github.com/417-72KI)
* Added fix for Xcode 12 - Warnings related to iOS 8 support (Swift Package Manager) #328
[@kikeenrique](https://github.com/kikeenrique)

## [9.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/9.0.0)

* Added support for Swift Package Manager and dropped OH from all class names.    
  [@jeffctown](https://github.com/jeffctown)


## [8.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/8.0.0)

* Update default Swift Version to 5.0
[@croig](https://github.com/CRoig)

>Notes:
> * No code changes were required (except from a little missing comma which caused a compilation error). Only xcshemes and xcodeproj were changed.

## [7.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/7.0.0)

* Updating default Swift Version to 4.2.  
  [@jeffctown](https://github.com/jeffctown)
* Updating example projects to Swift 4.2 and Xcode 10.1.  
  [@jeffctown](https://github.com/jeffctown)
* Updating iOS Lib Tests to have a minimum iOS version of 8.0.  
  [@jeffctown](https://github.com/jeffctown)

> Notes:  
> * Bumping this version to 7.0.0 because it's now using the Swift 4 APIs.  
> * This version is still compatible with Swift 3.x when integrating with CocoaPods, as CocoaPods uses the same `SWIFT_VERSION` as your app project does so it adapts automatically and it's transparent for users.
> * If you're using Carthage and need Swift 3.x compatibility, you can follow the tips in the installation instructions of the `README.md`.
> * CI is now only testing Swift 4.x on Xcode 9.1 and 10.1.  
> * Thank you to [@hellensoloviy](https://github.com/hellensoloviy), [@robertoferraz](https://github.com/robertoferraz), [@rckoenes](https://github.com/rckoenes), [@NikSativa](https://github.com/NikSativa) for their pull requests updating Swift!   

## [6.2.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/6.2.0)

* Enabled application extension API only.  
  [@lightsprint09](https://github.com/lightsprint09)
* Disabled a flaky redirect test and adding the known issue with redirects to the README.  
  [@jeffctown](https://github.com/jeffctown)
  [#301](https://github.com/AliSoftware/OHHTTPStubs/pull/301)
* Added `isMethodHEAD()` to the `Swift` helpers.  
  [@Simon-Kaz](https://github.com/Simon-Kaz)
  [#294](https://github.com/AliSoftware/OHHTTPStubs/pull/294)
* Fixed issue with not preserving correct headers when following 3xx
  redirects.  
  [@sberrevoets](https://github.com/sberrevoets)

## [6.1.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/6.1.0)

* Updated deployment target for the pod to 7.0 to remove warning for old APIs.  
  [@AliSoftware](https://github.com/AliSoftware)
* Fixed HTTP Method retention for 301,302,307,308 status redirects.  
  [@mikelupo](https://github.com/mikelupo)
* Added `hasJsonBody(_:)` matcher.  
  [@pimnijman](https://github.com/pimnijman)
* Added `onStubMissing` to report missing stubs.  
  [@c1ira](https://github.com/c1ira)
  [#264](https://github.com/AliSoftware/OHHTTPStubs/pull/264)
* Fixed `URLRequest.ohhttpStubs_httpBody` function in Swift 3 and 4.  
  [@mplorentz](https://github.com/mplorentz)
* Added absolute url matcher.  
  [@victorg1991](https://github.com/victorg1991)
  [#254](https://github.com/AliSoftware/OHHTTPStubs/pull/254)
* Fixed up empty lines with whitespace inside test case classes.  
  [@mikelupo](https://github.com/mikelupo)
  [#251](https://github.com/AliSoftware/OHHTTPStubs/pull/251)
* Fixed potential memory leaks with use of NSURLSession as detected by our devs.  
  [@mikelupo](https://github.com/mikelupo)
  [#250](https://github.com/AliSoftware/OHHTTPStubs/pull/250)
* Add precondition assertions in `isScheme` and `isHost` matchers and some documentation in `isHost`, `isScheme` and `isPath`.  
  [@Liquidsoul](https://github.com/Liquidsoul)
  [#248](https://github.com/AliSoftware/OHHTTPStubs/pull/248)

## [6.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/6.0.0)

* Made Swift 3 the default. `master` is now compatible with 3.0 and 3.1.  
  [@Liquidsoul](https://github.com/Liquidsoul)
  [@cohilla](https://github.com/cohilla)
  [#240](https://github.com/AliSoftware/OHHTTPStubs/pull/240)
* The `pod 'OHHTTPStubs/Swift'` subspec now includes the `URLSession` and `JSON` subspecs.  
  [@AliSoftware](https://github.com/AliSoftware)
* Added some matchers to the Swift APIs: `hasBody(…)`, `pathEndsWith(…)` and `pathMatches(…)`.  
  [@AliSoftware](https://github.com/AliSoftware)

> Notes:
>
> * Bumping this version to 6.0.0 because it's now using the Swift 3 APIs,
>   but in practice it's entirely retro-compatible with previous `5.2.3-swift3` branch
> * This version is still compatible with Swift 2.3 when integrating with CocoaPods, as CocoaPods uses the same `SWIFT_VERSION` as your app project does so it adapts automatically and it's transparent for users.
> * If you're using Carthage though, we stopped providing Swift-2.3-specific branches ourselves (too much maintainance work), but if you still need Swift 2.3 compatibility, you can follow the tips in the installation instructions of the `README.md`.

## [5.2.3](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/5.2.3)

* Reverted [#216](https://github.com/AliSoftware/OHHTTPStubs/pull/216) until better solution, as it was never active and can't make it compile for all subspec configurations.  
* Improved documentation about `dynamicType:` vs `type(of:)`.  
  [Antondomashnev](https://github.com/Antondomashnev)
  [#221](https://github.com/AliSoftware/OHHTTPStubs/pull/221)
* Fixed a race condition that occasionally prevented redirect callbacks.  
  [@morrowa](https://github.com/morrowa)
  [#224](https://github.com/AliSoftware/OHHTTPStubs/pull/224)
* Fixed response timing for zero-length stub data.  
  [@morrowa](https://github.com/morrowa)
  [#224](https://github.com/AliSoftware/OHHTTPStubs/pull/224)

## [5.2.2](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/5.2.2)

* Added `@discardableResult` to func stub for swift 3.  
  [@mrkite](https://github.com/mrkite), [#203](https://github.com/AliSoftware/OHHTTPStubs/pull/203)
* Removed `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` to avoid embedding Swift standard libraries when building with Carthage.  
  [@MattesGroeger](https://github.com/MattesGroeger)
  [#217](https://github.com/AliSoftware/OHHTTPStubs/pull/217)
  [@kylejm](https://github.com/kylejm)
  [#220](https://github.com/AliSoftware/OHHTTPStubs/pull/220)
* Add `OHHTTPStubs_HTTPBody` to `URLRequest` in Swift 3.0.  
  [@marcelofabri](https://github.com/marcelofabri)
  [#216](https://github.com/AliSoftware/OHHTTPStubs/pull/216)
* Migrate samples in `swift3` branch to Swift 3.  
  [@dhardiman](https://gitub.com/dhardiman)
  [#205](https://github.com/AliSoftware/OHHTTPStubs/pull/205)

## [5.2.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/5.2.1)

* Fix typos in README and documentation.  
  [@AliSoftware](https://github.com/AliSoftware)
  [@tmpsantos](https://github.com/tmpsantos)
  [#198](https://github.com/AliSoftware/OHHTTPStubs/pull/198)
* Fixes Swift 3.0 GM compatibility (`@escaping`) in the `swift-3.0` branch.  
  [@ikesyo](https://github.com/ikesyo)
  [#201](https://github.com/AliSoftware/OHHTTPStubs/pull/201)

## [5.2.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/5.2.0)

* Added Swift 2.3/Xcode 8 support. This is compatible both Swift 2.2/Xcode 7.3 and Swift 2.3/Xcode 8.  
  [@ikesyo](https://github.com/ikesyo)
  [#184](https://github.com/AliSoftware/OHHTTPStubs/pull/184)
* Added Swift 3.0 support.  
  [@mxcl](https://github.com/mxcl)
  [@Liquidsoul](https://github.com/Liquidsoul)
  [#192](https://github.com/AliSoftware/OHHTTPStubs/pull/192)
* Set deployment targets at the project level to be used in a universal target.  
  [@ikesyo](https://github.com/ikesyo)
  [#185](https://github.com/AliSoftware/OHHTTPStubs/pull/185)
* Fix: Carthage support and Examples configurations.  
  [@Liquidsoul](https://github.com/Liquidsoul)
  [#190](https://github.com/AliSoftware/OHHTTPStubs/issues/190)

## [5.1.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/5.1.0)

* Bugfix: task completion block never called when not following redirects.  
  [@adurdin](https://github.com/adurdin)
  [#175](https://github.com/AliSoftware/OHHTTPStubs/pull/175)
* Declare in the project settings that the library contains swift code.  
  [@rodericj](https://github.com/rodericj)
  [#173](https://github.com/AliSoftware/OHHTTPStubs/pull/173)
* Adjusted parsing of Mocktail files to allow headers to start on line 4.  
  [@Ashton-W](https://github.com/Ashton-W)
  [#172](https://github.com/AliSoftware/OHHTTPStubs/pull/172)
* Allows access to the `HTTPBody` of POST request when using `NSURLSession`
  [(Wiki entry)](https://github.com/AliSoftware/OHHTTPStubs/wiki/Testing-for-the-request-body-in-your-stubs)  
  [@iosphere](https://github.com/iosphere/)
  [#166](https://github.com/AliSoftware/OHHTTPStubs/pull/166)
  [#180](https://github.com/AliSoftware/OHHTTPStubs/pull/180)

## [5.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/5.0.0)

* Added `pathStartsWith(_:)` to the `Swift` helpers.  
  [@sdduursma](https://github.com/sdduursma)
  [#163](https://github.com/AliSoftware/OHHTTPStubs/pull/163)
* Added more logging blocks for debugging and better insight into when OHHTTPStubs returns stubs and redirects.  
  [@jzucker2](https://github.com/jzucker2)
  [#161](https://github.com/AliSoftware/OHHTTPStubs/pull/161)
* Added matchers that check whether a request has a particular header present, and a matcher to check if a request has a header with a key and value.  
  [@hq-mobile](https://github.com/hq-mobile)
  [#160](https://github.com/AliSoftware/OHHTTPStubs/pull/160)

_Note that this last change also changed the signature of the `onStubActivation:` (hence the bump to `5.0.0`) so you'll have to update your code if you used this for debugging your stubs._

## [4.8.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.8.0)

* Added `isEnabled` and `isEnabledForSessionConfiguration` getter methods.  
  [@jzucker2](https://github.com/jzucker2)
  [#159](https://github.com/AliSoftware/OHHTTPStubs/pull/159)

## [4.7.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.7.1)

* Bumps OSX Deployment Target to 10.9 to add Swift support.  
  [@JeanAzzopardi](https://github.com/JeanAzzopardi)
  [#154](https://github.com/AliSoftware/OHHTTPStubs/pull/154)
* Added the `${CURRENT_PROJECT_VERSION}` to the `Info.plist` files of the`OHHTTPStubs.framework` so it matches what is expected by iTunes Connect.  
  [@siemensikkema](https://github.com/siemensikkema)
  [#140](https://github.com/AliSoftware/OHHTTPStubs/pull/140)

## [4.7.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.7.0)

* Added `isMethodPATCH()` to the `Swift` helpers.  
  [@attheodo](https://github.com/attheodo)
  [#145](https://github.com/AliSoftware/OHHTTPStubs/issues/145)
* Fixed nullability annotation on `onStubActivation:` method parameter.  
  [@DerLobi](https://github.com/DerLobi)
  [#144](https://github.com/AliSoftware/OHHTTPStubs/pull/144)

## [4.6.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.5.1)

* Added `isMethodGET()`, `isMethodPUT()`, `isMethodPOST()` and `isMethodDELETE()` to the `Swift` helpers.  
  [#137](https://github.com/AliSoftware/OHHTTPStubs/issues/137)

## [4.5.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.5.1)

* Added missing `tvOS` and `watchOS` platforms to the `Swift` subspec.  
  [@pantuspavel](https://github.com/pantuspavel)
  [#136](https://github.com/AliSoftware/OHHTTPStubs/pull/136)

## [4.5.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.5.0) — tvOS

* Added support for tvOS.  
  [@tiagomartinho](https://github.com/tiagomartinho)
  [#134](https://github.com/AliSoftware/OHHTTPStubs/pull/134)

## [4.4.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.4.0)

* Fixed issue with Umbrella Headers.  
  [#127](https://github.com/AliSoftware/OHHTTPStubs/issues/127)
  [#131](https://github.com/AliSoftware/OHHTTPStubs/pull/131)
* Added methods for creating `HTTPStubsResponse`s from `NSURL`s that represent file system resources.  
  [@MaxGabriel](https://github.com/MaxGabriel)
  [#129](https://github.com/AliSoftware/OHHTTPStubs/pull/129)
* Bumped Swift subspec compatibility to OSX 10.9 instead of 10.7.


## [4.3.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.3.0)

* Xcode projects updated to Xcode 7.0 Final
* Added a `Swift` subspec that adds helper global functions to ease & make more compact the use of `OHHTTPStubs` from Swift 2.0  
  [#111](https://github.com/AliSoftware/OHHTTPStubs/issues/111)

> If you're using `OHHTTPStubs` in a **Swift 2.0** project, it's recommended to add `pod 'OHHTTPStubs/Swift` to your `Podfile` so you can use those handy helpers.

## [4.2.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.2.1)

* Fix the Examples Xcode project + lib Podfile that were referencing old target names  
  [@mikelupo](https://github.com/mikelupo)
  [#117](https://github.com/AliSoftware/OHHTTPStubs/pull/117)
* Added two new constants for download speed: `OHHTTPStubsDownloadSpeed1KBPS` = 1kbps and `OHHTTPStubsDownloadSpeedSLOW` = 1.5 kpbs.  
  [@mikelupo](https://github.com/mikelupo)
  [#114](https://github.com/AliSoftware/OHHTTPStubs/pull/114)

## [4.2.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.2.0) — Splitting in subspecs

* The `OHHTTPStubs` spec has been splitted into **multiple subspecs**:
  * The default subspec (used when you simply use `pod 'OHHTTPStubs'` in your `Podfile`) contains the subspecs `Core`, `NSURLSession`, `JSON` & `OHPathHelpers` (so that it matches the features that most people use).
  * Other optional subspecs are `HTTPMessage` and `Mocktail` (which are opt-in because used by much less people). If you want to use them, you'll need to request them explicitly in your `Podfile` using `pod 'OHHTTPStubs/Mocktail` for example.
* The iOS Unit Tests are now also run for the framework as well as for the static library, to ensure the tests pass in both contexts _(because frameworks sometimes introduce subtleties like when using `NSBundle`, so it's worth testing in that context too)_
* Added support for stubs written in the [Mocktail](https://github.com/square/objc-mocktail) format.  
  [@JinlianWang](https://github.com/JinlianWang)
  [#108](https://github.com/AliSoftware/OHHTTPStubs/pull/108)

## [4.1.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.1.0) — watchOS 2

* Added support for using `OHHTTPStubs` in watchOS 2.0 targets.
* Improved compatibility macros (nullability annotations) — and tested against Xcode 7 beta 4.

## [4.0.2](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.0.2)

* Fix `OHResourceBundle` name mismatch between header and implementation.  
  [@tibr](https://github.com/tibr)
  [#103](https://github.com/AliSoftware/OHHTTPStubs/pull/103)

## [4.0.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.0.1)

* Fix threading in `NSURLProtocol` subclass calling `NSURLProtocolClient` callbacks from wrong thread.  
  [@nsprogrammer](https://github.com/nsprogrammer)
  [#96](https://github.com/AliSoftware/OHHTTPStubs/pull/96)

## [4.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/4.0.0) — Improvements for Swift

* Annotated the library with _nullability_ attributes to generate a better API when used in Swift
* Migrated the path utility macros to functions in `OHPathHelpers.h`, for Swift compatibility.  
  [#100](https://github.com/AliSoftware/OHHTTPStubs/issues/100)
* Added a complete Swift Demo Project.  
  [#88](https://github.com/AliSoftware/OHHTTPStubs/issues/88)
* Removed the  `XCTestExpectation` subspec that was added for Xcode 5 support — Now that Xcode 6 is widely adopted, you shouldn't need this anymore (but in case you still need it, I will probably create a dedicated pod for that)

## [3.1.12](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.12)

* Fixed issue with HTTP 300 return code (multiple-choice) that is not supposed to redirect.  
  [@tarbrain](https://github.com/tarbrain)
  [#92](https://github.com/AliSoftware/OHHTTPStubs/pull/92)

## [3.1.11](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.11)

* Added [Carthage](https://github.com/Carthage/Carthage) support
* Splitted the Xcode projects for more clarity (one dedicated to build the lib and run Unit Tests, and one for the Demo)
* Got rid of the `git submodule` used for Unit Tests against [AFNetworking](https://github.com/AFNetworking/AFNetworking) — it is now imported using [CocoaPods](http://cocoapods.org) and only for the lib's Unit Tests targets.  
  [@corinnekrych](https://github.com/corinnekrych)
  [#90](https://github.com/AliSoftware/OHHTTPStubs/pull/90)
* Improved [Travis-CI](https://travis-ci.org/AliSoftware/OHHTTPStubs) integration. We now use a build matrix to have paralellized and independant builds for each scheme (iOS Static Lib, iOS Dynamic Framework, OSX Framework)
* Fixed [#80](https://github.com/AliSoftware/OHHTTPStubs/issues/80) again (there was still an issue for people using Xcode 5 & SDK 7.1… if those people still exists)

## [3.1.10](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.10)

* Fix headers for people still building with Xcode 5 & SDK 7 ([#80](https://github.com/AliSoftware/OHHTTPStubs/issues/80))

## [3.1.9](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.9)

* Use `NS_DESIGNATED_INITIALIZER` macro on designated initializer methods ([#79](https://github.com/AliSoftware/OHHTTPStubs/pull/79))

## [3.1.8](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.8)

* Use `application/json` instead of `text/json` in `README`'s example ([#75](https://github.com/AliSoftware/OHHTTPStubs/pull/75))
* Fixed an issue with empty files (when using `responseWithFileAtPath:statusCode:headers:` but the file at the specified path is empty)

## [3.1.7](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.7)

* Added `DEFINES_MODULE` Flag to be easily imported in Swift ([#74](https://github.com/AliSoftware/OHHTTPStubs/pull/74))

_(I also moved [Travis-CI build system](https://travis-ci.org/AliSoftware/OHHTTPStubs) so it now uses `xcpretty` instead of `xctool` to run Unit Tests)_

## [3.1.6](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.6)

* Fixed issue with the main thread stalling when an `NSException` was raised in the response block
* Fixed an issue with `OHHTTPStubs/XCTestExpectation` conditional compilation in Xcode 6.0 & OSX SDK.  
  _(the condition was previously testing available SDKs instead of Xcode version, which led to errors with Xcode 6.0 not having the latest 10.10 SDK yet, but still having the `XCTestExpectation` already anyway)_

## [3.1.5](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.5)

* Migrated Unit Tests to XCTest.
* Added `XCTestExpectation` subspec containing my own implementation for Xcode 5 support

## [3.1.4](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.4)

* Fix issue that made stubs never being called on iOS8 (#65).

> _As of Xcode6 Beta4, **`OHHTTPStubs` compatibility with iOS8** has been validated now._


## [3.1.3](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.3)

* Fix #66: Use the ivar directly in initialization (to avoid KVO side effects)

## [3.1.2](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.2)

* Fix broken link in README (#61)
* Don't override Content-Length header when already set (#62)

## [3.1.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.1)

* Fixing a crash when using very very long data #57/#59
* Fixing issue #51 regarding a probable race condition when stubs were removed before the request has finished
* Shorten the README.md file and moved all the usage examples in a dedicated wiki page to avoid a endless and frightening README

## [3.1.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.1.0)

* The `HTTPStubsDescriptor` protocol now inherits from the `NSObject` protocol

## [3.0.4](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.0.4)

Fixing issue #47 when stubs were not called, especially when the `OHHTTPStubs` pod were loaded both by the application AND the test target/bundle. See also [[A tricky case with Application Tests]].

* `NSURLSessionConfiguration` 's swizzling (to add automatic support of `OHHTTPStubs` to `NSURLSession`) is now done in the `+load` method of an `NSURLSessionConfiguration` category, to be sure it is loaded (and swizzled) only once, even if `OHHTTPStubs` is loaded by two different bundles.
* The stubs activation of `NSURLSessionConfiguration` no longer uses `objc_getClass` but uses a call to the `OHHTTPStubs` class instead, which ensure that it uses the correct `OHHTTPStubs` class in the current bundle instead of always using the one loaded from the main bundle.

## [3.0.3](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.0.3)

* Adding Mac framework & Mac Test Target (#44)
* Adding known limitations in README

## [3.0.2](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.0.2)

* Fixed issue with cookies when `request.URL` is `nil` ([#39](https://github.com/AliSoftware/OHHTTPStubs/pull/39))
* Fixed missing `-ObjC` flag in Unit Tests target _(that made it unable to call category methods)_
* Fixed Unit Tests on iOS6 _(`NSURLSession`-related Unit Tests now only executed when run on iOS7+ or OSX10.9+, and skipped if targeted for an earlier OS version, as `NSURLSession` was not available then)_

## [3.0.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.0.1)

* Fixed issue with `NSURLSessionConfiguration` auto-swizzling (#37 & #38)

> _Now `OHHTTPStubs` automagically works with `NSURLSessionConfiguration` **without the need** to enable it for every `NSURLSessionConfiguration` before creating the `NSURLSession`: the `defaultSessionConfiguration` and `ephemeralSessionConfiguration` are now preconfigured automatically to work with `OHHTTPStubs`)_

## [3.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/3.0.0)

* Removed deprecated methods.

> The Old API has now totally disappeared, leaving only a clean and simple API without the spam due to old deprecated methods.

Note: **If you have already removed the calls to all `OHHTTPStubs` deprecated API in your code, you can switch to this `3.0.0` version without any further changes in your code**.

## [2.4.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/2.4.0)

* Added support for `NSURLSession` (thx to @ndonald2) [#31](https://github.com/AliSoftware/OHHTTPStubs/issues/31) [#34](https://github.com/AliSoftware/OHHTTPStubs/issues/34)

## [2.3.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/2.3.1)

* Fixed bug with HTTPStubsResponse+JSON when `nil` headers dictionary

## [2.3.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/2.3.0)

* Added the ability to give a name to a stub, for debugging purposes (property `name` of `id<HTTPStubsDescriptor>`)
* Added `allStubs` method to list all installed stubs (with their name if they have one, see previous point)
* Added `+[OHHTTPStubs onStubActivation:]` method to execute arbitrary code each time a stub is activated. Useful to log which stub is used for each request for example.

## [2.2.1](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/2.2.1)

* Complete refactoring to use `NSInputStream` instead of direct use of `NSData` (Thanks to @kcharwood - #28)
* Some other code refactoring to split the code in categories and make it clearer
* Some API changes to make `OHHTTPStubs` to fit the new possibility of setting both `requestTime` and `responseTime`.
  * Old API is still there but deprecated, and will be removed in next major version
  * To convert to the new API, you will mainly simply:
     * extract the `responseTime:` parameter to a method call of its own (`return [HTTPStubsResponse responseWithData:data statusCode:code responseTime:time headers:header];` will become `return [[HTTPStubsResponse responseWithData:data statusCode:code headers:headers] responseTime:time];` etc.)
     * convert `responseWithFile:filename` to `responseWithFileAtPath:OHPathForFileInBundle(filename,nil)`

> Note: version `2.1.0-RC`, `2.1.0-rc.1`, `2.2.0-RC` and `2.2.1-RC` were intermediate Release Candidate versions during the big refactoring and migration to `2.2.1`, with the same new features as listed above basicaly, but without the last-minute bugfixes before official release.

## [2.0.0](https://github.com/AliSoftware/OHHTTPStubs/releases/tag/2.0.0)

* Simplified API
  * removed instance methods, no more public `sharedInstance`: directly call class methods on the `OHHTTPStubs` class
  * The old and problematic `addRequestHandler:` method has been deprecated and should not be used anymore. Use `stubRequestsPassingTest:withStubResponse:` instead, which is more efficient
* Added API documentation in the headers
* Remove all internal uses of Apple's private APIs

> _Be careful: if you forgot to remove your use of `OHHTTPStubs` and your stubs from the binary you sent to the AppStore, your app would have been rejected by Apple before 2.0.0, as it was using private API (which was a way to make sure not to forget to remove them), but now it would be accepted silently. So don't forget to remove your stubs and `OHHTTPStubs` from your final binary!_

## [1.2.2](https://github.com/AliSoftware/OHHTTPStubs/tree/1.2.2)

* Fixed Deadlock introduced by 1.2.1

## [1.2.1](https://github.com/AliSoftware/OHHTTPStubs/tree/1.2.1)

* Improved thread-safety (#21)
* Stop sending messages to `NSURLProtoclClient` after `stopLoading`

> _This version is buggy as it introduced a deadlock when performing a request on the main thread. 1.2.2 fixes that issue._

## [1.2.0](https://github.com/AliSoftware/OHHTTPStubs/tree/1.2.0)

* Added support for "HTTP Message Data" stubs generated with `curl -is <someurl>` to replay them easily (#27). See the `README.md` for more info
* Added redirect support for 3xx response codes (#23)
* Dropped non-ARC support. Now `OHHTTPStubs` is to be compiled using ARC. _(This should not change anything as it is intended to be integrated using CocoaPods or compiled in a separate xcodeproj anyway)_

## [1.1.2](https://github.com/AliSoftware/OHHTTPStubs/tree/1.1.2)

Easier integration process:

* Use `#import <OHHTTPStubs/OHHTTPStubs.h>` again
* But adding the path to the library headers in your application project's `HEADER_SEARCH_PATH` is no longer needed!

## [1.1.1](https://github.com/AliSoftware/OHHTTPStubs/tree/1.1.1)

* Fixed crash when calling "setEnabled:" / "registerClass:" multiple times
* New integration process: we don't use the `PortableLibrary.xcconfig` anymore (as it generated problems for people using configuration with names other than "Debug" and "Release"). _(1)_

_You will now have to indicate the folder containing headers for `OHHTTPStubs` in your `HEADER_SEARCH_PATH` Build Settings, and we are back to `#import "OHHTTPStubs.h"` until a better solution is found_

> _(1) This modification for the integration process did only last for version 1.1.1. Version 1.1.2 restored `#import <OHHTTPStubs/OHHTTPStubs.h>` (but using a much better solution than the previous xcconfig used) and filling `HEADER_SEARCH_PATH` is no longer needed in further versions. See changelog for 1.1.2 above._

## [1.1.0](https://github.com/AliSoftware/OHHTTPStubs/tree/1.1.0)

* Added new API `shouldStubRequest:withRequestHandler:` to avoid useless building of stubbed response like `addRequestHandler:` does

## [1.0.6](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.6)

* Adding support for cookies (Set-Cookie headers)

## [1.0.5](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.5)

* Added Unit Tests
* Removed calls to the deprecated `dispatch_get_current_queue()` GCD function (was used with `dispatch_after` to add fake delay to stubbed responses)

## [1.0.4](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.4)

* Fixed #6 : "responseWithError:" released response object too soon

## [1.0.3](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.3)

* Fixed small compilation issues #4 (issue in sample code) & #5 (ARC invalid cast)

## [1.0.2](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.2)

* Embedded `OHHTTPStubs` in a neat static library for nicer integration in your Xcode4 workspaces.

## [1.0.1](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.1)

* Fix issue when used in a SenTestCase

## [1.0.0](https://github.com/AliSoftware/OHHTTPStubs/tree/1.0.0)

* Cleaning API, added `removeLastHandler` and `removeRequestHandler:` method.
* Now first stable API in this version.
* Example project now compatible with ARC and non-ARC environments

## [0.2.0](https://github.com/AliSoftware/OHHTTPStubs/tree/0.2.0)

* Added Example project
* Added ARC support
* Some fixes

## [0.1.0](https://github.com/AliSoftware/OHHTTPStubs/tree/0.1.0)

* Initial version
