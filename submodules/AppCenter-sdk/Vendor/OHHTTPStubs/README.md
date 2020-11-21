OHHTTPStubs
===========

[![Platform](http://cocoapod-badges.herokuapp.com/p/OHHTTPStubs/badge.png)](http://cocoadocs.org/docsets/OHHTTPStubs)
[![Language: Swift-2.x/3.x/4.x/5.x](https://img.shields.io/badge/Swift-2.x%2F3.x%2F4.x%2F5.x-orange.svg)](https://swift.org)
[![Build Status](https://travis-ci.org/AliSoftware/OHHTTPStubs.svg?branch=master)](https://travis-ci.org/AliSoftware/OHHTTPStubs)

[![Version](http://cocoapod-badges.herokuapp.com/v/OHHTTPStubs/badge.png)](http://cocoadocs.org/docsets/OHHTTPStubs)
[![Carthage Supported](https://img.shields.io/badge/carthage-supported-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Swift Package Manager Supported](https://img.shields.io/badge/spm-supported-4BC51D.svg?style=flat)](https://swift.org/package-manager/)


`OHHTTPStubs` is a library designed to stub your network requests very easily. It can help you:

* test your apps with **fake network data** (stubbed from file) and **simulate slow networks**, to check your application behavior in bad network conditions
* write **unit tests** that use fake network data from your fixtures.

It works with `NSURLConnection`, `NSURLSession`, `AFNetworking`, `Alamofire` or any networking framework that use Cocoa's URL Loading System.

[<img alt="Donate" src="https://www.paypalobjects.com/webstatic/mktg/merchant_portal/button/donate.en.png" height="32px">](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=TRTU3UEWEHV92 "Donate")

----

# Documentation & Usage Examples

`OHHTTPStubs` headers are fully documented using Appledoc-like / Headerdoc-like comments in the header files. You can also [read the **online documentation** here](http://cocoadocs.org/docsets/OHHTTPStubs).


## Basic example

<details>
<summary>In Objective-C</summary>

```objc
[HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
  return [request.URL.host isEqualToString:@"mywebservice.com"];
} withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
  // Stub it with our "wsresponse.json" stub file (which is in same bundle as self)
  NSString* fixture = OHPathForFile(@"wsresponse.json", self.class);
  return [HTTPStubsResponse responseWithFileAtPath:fixture
            statusCode:200 headers:@{@"Content-Type":@"application/json"}];
}];
```

</details>

<details open=1>
<summary>In Swift</summary>

This example is using the Swift helpers found in `OHHTTPStubsSwift.swift` provided by the `OHHTTPStubs/Swift` subspec or `OHHTTPStubs` package.
 
```swift
stub(condition: isHost("mywebservice.com")) { _ in
  // Stub it with our "wsresponse.json" stub file (which is in same bundle as self)
  let stubPath = OHPathForFile("wsresponse.json", type(of: self))
  return fixture(filePath: stubPath!, headers: ["Content-Type":"application/json"])
}
```

**Note**: if you're using `OHHTTPStubs`'s Swiftier API (`OHHTTPStubsSwift.swift` and the `Swift` subspec or `OHTTPStubsSwift` package), you can also compose the matcher functions like this: `stub(isScheme("http") && isHost("myhost")) { … }`
</details>

## More examples & Help Topics
    
* For a lot more examples, see the dedicated "[Usage Examples](https://github.com/AliSoftware/OHHTTPStubs/wiki/Usage-Examples)" wiki page.
* The wiki also contain [some articles that can help you get started](https://github.com/AliSoftware/OHHTTPStubs/wiki) with (and troubleshoot if needed) `OHHTTPStubs`.

## Recording requests to replay them later

Instead of writing the content of the stubs you want to use manually, you can use tools like [SWHttpTrafficRecorder](https://github.com/capitalone/SWHttpTrafficRecorder) to record network requests into files. This way you can later use those files as stub responses.  
This tool can record all three formats that are supported by `OHHTTPStubs` (the `HTTPMessage` format, the simple response boby/content file, and the `Mocktail` format).

_(There are also other ways to perform a similar task, including using `curl -is <url> >foo.response` to generate files compatible with the `HTTPMessage` format, or using other network recording libraries similar to `SWHttpTrafficRecorder`)._

# Compatibility

* `OHHTTPStubs` is compatible with **iOS5+**, **OS X 10.7+**, **tvOS**.
* `OHHTTPStubs` also works with `NSURLSession` as well as any network library wrapping them.
* `OHHTTPStubs` is **fully compatible with Swift 3.x, 4.x and Swift 5.x**.

_[Nullability annotations](https://developer.apple.com/swift/blog/?id=25) have also been added to the ObjC API to allow a cleaner API when used from Swift even if you don't use the dedicated Swift API wrapper provided by `OHHTTPStubsSwift.swift`._

<details>
<summary><b>Updating to Version 9.0+</b></summary>

* All classes dropped the `OH` prefix (`OHHHTTPStubs` -> `HTTPStubs`, `OHHTTPStubsResponse` -> `HTTPStubsResponse`, etc).
* The `OHPathHelpers` class was renamed `HTTPStubsPathHelpers`.
* No method and module names were changed.
</details>


# Installing in your projects

## CocoaPods

Using [CocoaPods](https://guides.cocoapods.org) is the recommended way.

* If you **intend to use `OHHTTPStubs` from Objective-C only**, add `pod 'OHHTTPStubs'` to your `Podfile`.
* If you **intend to use `OHHTTPStubs` from Swift**, add `pod 'OHHTTPStubs/Swift'` to your `Podfile` instead.

```ruby
pod 'OHHTTPStubs/Swift' # includes the Default subspec, with support for NSURLSession & JSON, and the Swiftier API wrappers
```

### All available subspecs

`OHHTTPStubs` is split into subspecs so that when using Cocoapods, you can get only what you need, no more, no less.

* The default subspec includes `NSURLSession`, `JSON`, and `OHPathHelpers`
* The `Swift` subspec adds the Swiftier API to that default subspec
* `HTTPMessage` and `Mocktail` are opt-in subspecs: list them explicitly if you need them
* `OHPathHelpers` doesn't depend on `Core` and can be used independently of `OHHTTPStubs` altogether

<details>
<summary>List of all the subspecs & their dependencies</summary>

Here's a list of which subspecs are included for each of the different lines you could use in your `Podfile`:

| Subspec                           | Core | NSURLSession | JSON | Swift | OHPathHelpers | HTTPMessage | Mocktail |
| --------------------------------- | :--: | :----------: | :--: | :---: | :-----------: | :---------: | :------: |
| `pod 'OHHTTPStubs'`               | ✅   | ✅           | ✅   |       | ✅            |             |          |
| `pod 'OHHTTPStubs/Default'`       | ✅   | ✅           | ✅   |       | ✅            |             |          |
| `pod 'OHHTTPStubs/Swift'`         | ✅   | ✅           | ✅   | ✅    | ✅            |             |          |
| `pod 'OHHTTPStubs/Core'`          | ✅   |              |      |       |               |             |          |
| `pod 'OHHTTPStubs/NSURLSession'`  | ✅   | ✅           |      |       |               |             |          |
| `pod 'OHHTTPStubs/JSON'`          | ✅   |              | ✅   |       |               |             |          |
| `pod 'OHHTTPStubs/OHPathHelpers'` |      |              |      |       | ✅            |             |          |
| `pod 'OHHTTPStubs/HTTPMessage'`   | ✅   |              |      |       |               | ✅          |          |
| `pod 'OHHTTPStubs/Mocktail'`      | ✅   |              |      |       |               |             | ✅       |

</details>

## Swift Package Manager

`OHHTTPStubs` is compatible with Swift Package Manager, and provides 2 targets for consumption: `OHHTTPStubs` and `OHHTTPStubsSwift`.

* `OHHTTPStubs` is equivalent to the `OHHTTPStubs` subspec.
* `OHHTTPStubsSwift` is equivalent to the `OHHTTPStubs/Swift` subspec.

_Note: We currently do not have support for the HTTPMessage or Mocktail subspecs in Swift Package Manager.  If you are interested in these, please open an issue to explain your needs._

## Carthage

`OHHTTPStubs` is also compatible with Carthage. Just add it to your `Cartfile`.

_Note: The `OHHTTPStubs.framework` built with Carthage will include **all** features of `OHHTTPStubs` turned on (in other words, all subspecs of the pod), including `NSURLSession` and `JSON` support, `OHPathHelpers`, `HTTPMessage` and `Mocktail` support, and the Swiftier API._

## Using the right Swift version for your project

`OHHTTPStubs` supports Swift 3.0 (Xcode 8+), Swift 3.1 (Xcode 8.3+), Swift 3.2 (Xcode 9.0+), Swift 4.0 (Xcode 9.0+), Swift 4.1 (Xcode 9.3+), Swift 4.2 (Xcode 10+), Swift 5.0 (Xcode 10.2), and Swift 5.1 (Xcode 11) however we are only testing Swift 4.x (using Xcode 9.1 and 10.1) and Swift 5.x (using Xcode 10.2 AND 11) in CI.

Here are some details about the correct setup you need depending on how you integrated `OHHTTPStubs` into your project.

<details>
<summary><b>CocoaPods: nothing to do</b></summary>

If you use CocoaPods version [`1.1.0.beta.1`](https://github.com/CocoaPods/CocoaPods/releases/tag/1.1.0.beta.1) or later, then CocoaPods will compile `OHHTTPStubs` with the right Swift Version matching the one you use for your project automatically. You have nothing to do! 🎉

For more info, see [CocoaPods/CocoaPods#5540](https://github.com/CocoaPods/CocoaPods/pull/5540) and [CocoaPods/CocoaPods#5760](https://github.com/CocoaPods/CocoaPods/pull/5760).
</details>

<details>
<summary><b>Carthage: choose the right version</b></summary>

The project is set up with `SWIFT_VERSION=5.0` on `master`.

This means that the framework on `master` will build using:

* Swift 5.1 on Xcode 11
* Swift 5.0 on Xcode 10.2
* Swift 4.2 on Xcode 10.1
* Swift 4.0 on Xcode 9.1

If you want Carthage to build the framework with Swift 3.x you can:

 * either use an older Xcode version
 * or use the previous version of `OHHTTPStubs` (6.2.0) — whose `master` branch uses `3.0`
 * or fork the repo just to change the `SWIFT_VERSION` build setting to `3.0`
 * or build the framework passing a `SWIFT_VERSION` to carthage via `XCODE_XCCONFIG_FILE=<config file declaring SWIFT_VERSION> carthage build`

</details>

# Special Considerations

## Using OHHTTPStubs in your unit tests

`OHHTTPStubs` is ideal to write unit tests that normally would perform network requests. But if you use it in your unit tests, don't forget to:

* remove any stubs you installed after each test — to avoid those stubs to still be installed when executing the next Test Case — by calling `[HTTPStubs removeAllStubs]` in your `tearDown` method. [see this wiki page for more info](https://github.com/AliSoftware/OHHTTPStubs/wiki/Remove-stubs-after-each-test)
* be sure to wait until the request has received its response before doing your assertions and letting the test case finish (like for any asynchronous test). [see this wiki page for more info](https://github.com/AliSoftware/OHHTTPStubs/wiki/OHHTTPStubs-and-asynchronous-tests)

## Automatic loading

`OHHTTPStubs` is automatically loaded and installed (at the time the library is loaded in memory), both for:

* requests made using `NSURLConnection` or `[NSURLSession sharedSession]` — [thanks to this code](https://github.com/AliSoftware/OHHTTPStubs/blob/master/OHHTTPStubs/Sources/OHHTTPStubs.m#L107-L113)
* requests made using a `NSURLSession` that was created via `[NSURLSession sessionWithConfiguration:…]` and using either `[NSURLSessionConfiguration defaultSessionConfiguration]` or `[NSURLSessionConfiguration ephemeralSessionConfiguration]` configuration — thanks to [method swizzling](http://nshipster.com/method-swizzling/) done [here in the code](https://github.com/AliSoftware/OHHTTPStubs/blob/master/OHHTTPStubs/Sources/NSURLSession/HTTPStubs+NSURLSessionConfiguration.m).

If you need to disable (and re-enable) `OHHTTPStubs` — globally or per `NSURLSession` — you can use `[HTTPStubs setEnabled:]` / `[HTTPStubs setEnabled:forSessionConfiguration:]`.

## Known limitations

* `OHHTTPStubs` **can't work on background sessions** (sessions created using `[NSURLSessionConfiguration backgroundSessionConfiguration]`) because background sessions don't allow the use of custom `NSURLProtocols` and are handled by the iOS Operating System itself.
* `OHHTTPStubs` don't simulate data upload. The `NSURLProtocolClient` `@protocol` does not provide a way to signal the delegate that data has been **sent** (only that some has been loaded), so any data in the `HTTPBody` or `HTTPBodyStream` of an `NSURLRequest`, or data provided to `-[NSURLSession uploadTaskWithRequest:fromData:];` will be ignored, and more importantly, the `-URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:` delegate method will never be called when you stub the request using `OHHTTPStubs`.
* `OHTTPStubs` **has a known issue with redirects** that we believe is an Apple bug.  It has been discussed [here](https://github.com/AliSoftware/OHHTTPStubs/issues/230) and [here](https://github.com/AliSoftware/OHHTTPStubs/issues/280).  The actual result of this bug is that redirects with a zero second delay may nondeterministically end up with a null response.

_As far as I know, there's nothing we can do about those three limitations. Please let me know if you know a solution that would make that possible anyway._


## Submitting to the App Store

`OHHTTPStubs` **can be used** on apps submitted **on the App Store**. It does not use any private API and nothing prevents you from shipping it.

But you generally only use stubs during the development phase and want to remove your stubs when submitting to the App Store. So be careful to only include `OHHTTPStubs` when needed (only in your test targets, or only inside `#if DEBUG` sections, or by using [per-Build-Configuration pods](https://guides.cocoapods.org/syntax/podfile.html#pod)) to avoid forgetting to remove it when the time comes that you release for the App Store and you want your requests to hit the real network!



# License and Credits

This project and library has been created by Olivier Halligon ([@aligatr](https://twitter.com/aligatr) on Twitter) and is under the MIT License.

It has been inspired by [this article from InfiniteLoop.dk](https://web-beta.archive.org/web/20161219003951/http://www.infinite-loop.dk/blog/2011/09/using-nsurlprotocol-for-injecting-test-data/).

I would also like to thank:

* Sébastien Duperron ([@Liquidsoul](https://github.com/Liquidsoul)) for helping me maintaining this library, triaging and responding to issues and PRs
* Kevin Harwood ([@kcharwood](https://github.com/kcharwood)) for migrating the code to `NSInputStream`
* Jinlian Wang ([@JinlianWang](https://github.com/JinlianWang)) for adding Mocktail support
* and everyone else who contributed to this project on GitHub somehow.

If you want to support the development of this library, feel free to [<img alt="Donate" src="https://www.paypalobjects.com/webstatic/mktg/merchant_portal/button/donate.en.png" height="25px">](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=TRTU3UEWEHV92 "Donate"). Thanks to all contributors so far!
