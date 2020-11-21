Version 7.1.2
-------------
_23 Sep 2019_

**Fixes:**

- Fix warning about double-quoted includes in public headers.


Version 7.1.1
-------------
_15 Jun 2018_

**Fixes:**

- Fixed crash with HCArgumentCaptor capturing objects that don't conform to NSCopyable.


Version 7.1.0
-------------
_21 Mar 2018_

**Features:**

- Made OCHamcrest/OCHamcrestIOS into modules, so you can `@import` them. CocoaPods users should specify `use_frameworks!`

**Fixes:**

- Fixed crash with HCArgumentCaptor capturing blocks.


Version 7.0.2
-------------
_19 Sep 2017_

**Fixes:**

- Fixed new warnings from Xcode 9.


Version 7.0.1
-------------
_12 Aug 2017_

**Fixes:**

- Remove exposed instance variables that triggered warnings for `-Wobjc-interface-ivars`.

I doubt that it affects anyone, but converting public ivars to private properties does have the
potential to break backwards compatibility. Please notify me if you have any code that complains.

**Project changes:**

- Increase macOS deployment target to 10.10. (iOS was already at 8.0.)

(Version 7.0.0 mistakenly required projects to Enable Modules and had out-of-date documentation.)


Version 6.1.1
-------------
_06 Mar 2017_

**Fixes:**

- Fixed nullability mistake: HCWrapInMatcher(nil) should return nil.


Version 6.1.0
-------------
_17 Feb 2017_

**Features:**

- Adopt latest Objective-C annotations for designated initializers, unavailable initializers, typed arrays, nullability.


Version 6.0.0
-------------
_04 Aug 2016_

**Features:**

- Improved mismatch descriptions for `contains`, `containsIn` when actual collection exceeds expected size.

**Deleted:**

- `equalToIgnoringWhiteSpace` matcher (deprecated in v5.4.0)
- HCCollectMatchers (deprecated in v5.3.0)

**Project changes:**

- Increased deployment targets to OS X 10.9, iOS 7.0.


Version 5.4.0
-------------
_03 Jun 2016_

**Features:**

- Added `captureEnabled` property to HCArgumentCaptor to control whether subsequent matched values are captured.

**Improvements:**

- Updated CocoaPods instructions and examples to CocoaPods 1.0.

**Deprecated:**

- `equalToIgnoringWhiteSpace` has been renamed to `equalToCompressingWhiteSpace`.
- Known issue: warning on this deprecation


Version 5.3.0
-------------
_22 May 2016_

**Fixes:**

- Removed semicolons that triggered warnings for `-Wsemicolon-before-method-body`. _Thanks to: Sylvain Defresne_
- Describe `isIn` matcher in README.

**Features:**

- Rewrote `assertThatAfter` to use runloop observer instead of while loop comparing dates. The condition is now tested on every pump of the runloop instead of polling after a predefined delay.  _Thanks to: Dan Fleming_

**Deprecated:**

- Deprecated HCCollectMatchers. Instead, follow the example of HCAllOf.m and break it into two steps: HCCollectItems, then HCWrapIntoMatchers. This will let you expose a new interface to your matcher that takes an NSArray.


Version 5.2.0
-------------
_16 Jan 2016_

**Fixes:**

- Fixed umbrella header for Carthage. _Thanks to: Sylvain Rebaud, Engin Kurutepe_

**Features:**

- Improved mismatch descriptions for `allOf`, `allOfIn`.


Version 5.1.0
-------------
_14 Dec 2015_

**Features:**

- Added HCDescribeMismatch, a helper function to describe mismatches the way `assertThat` does.
- Added Carthage support for Mac, iOS, watchOS and tvOS. _Thanks to: Nikolaj Schumacher_


Version 5.0.0
-------------
_02 Nov 2015_

For detailed discussion on v5.0.0, see https://qualitycoding.org/ochamcrest-v5-0-0/

**Features:**

- Instead of enabling short syntax by defining HC_SHORTHAND, short syntax is now enabled by default.
  To disable it, #define HC_DISABLE_SHORT_SYNTAX.
- Matchers which take nil-terminated lists have "In" variants which take a single NSArray, like
  `allOfIn`. The matcher `hasEntriesIn` is an exception and takes an NSDictionary.
- Improved documentation on all matchers. Documentation is now shown for matchers with fixed numbers
  of arguments. All matchers provide argument hinting.

**Renamed:**

- Renamed long syntax for `containsInRelativeOrder` from prefix hc_ to HC_ to conform to other
  matchers.

**Deleted:**

- `equalToBool` matcher (deprecated in v4.1.0)
- `containsString` matcher (deprecated in v4.2.0)
- `assertThatAfter`/`futureValueOf` (deprecated in v4.2.0)
- `HC_testFailureHandlerChain()` (deprecated in v4.2.0)


Version 4.3.2
-------------
_31 Oct 2015_

**Project changes:**

- Enabling "Symbols hidden by default" in 4.3.1 was overkill, preventing people from using the
  prebuilt Mac framework.


Version 4.3.1
-------------
_24 Oct 2015_

**Project changes:**

- Remove debug symbols from Release configuration, which bloated the libraries and kept folks from
  using the prebuilt iOS framework.


Version 4.3.0
-------------
_11 Oct 2015_

**Features:**

- New matcher `containsInRelativeOrder` matches collections containing items in relative order.
- New matcher HCArgumentCaptor matches anything, capturing matched values.

**Project changes:**

- Updated project settings to Xcode 7, with tests now run by XCTest.


Version 4.2.0
-------------
_11 Sep 2015_

**Fixes:**

- Fixed "Incompatible pointer types sending 'Class' to parameter of type 'NSString *'" warning on
  `instanceOf`.

**Features:**

- Improved readability of asynchronous tests: `assertWithTimeout(1, thatEventually(var), is(@10));`
- Added ability to add custom test failure reporter. See HCTestFailureReporterChain.

**Deprecated:**

- Deprecated `containsString`; use `containsSubstring` instead. `containsString` clashes with an
  NSString method introduced in iOS 8.
- Deprecated `assertThatAfter`/`futureValueOf`. Use `assertWithTimeout`/`thatEventually` instead.
- Deprecated `HC_testFailureHandlerChain()`; use `[HCTestFailureReporterChain reporterChain]`
  instead.


Version 4.1.1
-------------
_31 Dec 2014_

- Oops! Add the new features to OCHamcrest.h


Version 4.1.0
-------------
_30 Dec 2014_

**Fixes:**

- Fixed crash when OCHamcrest tries to describe an OCMockito mock object. _Thanks to: Michael Seghers_
- Fixed crash when `equalToBool` attempts to match a non-number.

**Features:**

- `assertThatAfter` tests asynchronous code, retrying the assertion until a given timeout.
  Wrap the code you want to evaluate in `futureValueOf`. _Thanks to: Sergio Padrino_
- New matcher `everyItem` matches collections if every item satisfies a given matcher.
- New matcher `throwsException` matches a block if it throws an exception satisfying a given
  matcher.
- New matchers `isTrue` and `isFalse` match non-zero and zero NSNumbers. Intended to replace
  `equalToBool`.

**Improvements:**

- Added new base class HCDiagnosingMatcher to simplify complex matchers.
- `equalToBool` matcher can no longer be created with a value other than YES or NO. This especially
  avoids the accidental @YES.
- Improved ordered comparison matchers (`greaterThan`, etc.) so that when the given object can't be
  compared, the matchers return NO instead of throwing an exception.
- Improved mismatch descriptions for `hasItem`.
- Improved mismatch descriptions for `hasProperty` to show actual property value or "no property".
- Improved mismatch descriptions for `onlyContains`, especially in reporting all elements that don't
  match.
- Updated project to make it run-path dependent. _Thanks to: csano_

**Deprecated:**

- `equalToBool` deprecated in favor of `isTrue` and `isFalse`. `equalToBool(YES)` had too much
  potential for semantic error since any non-zero number evaluates to true.



Version 4.0.1
-------------
_04 Jun 2014_

**Project changes:**

- Increased deployment targets to OS X 10.8, iOS 6.0.


Version 4.0.0
-------------
_10 May 2014_

This is a refactoring release with potential backwards compatibility issues for writers of custom
matchers:

- Almost all ivars have been converted to hidden properties. Let me know if this trips you up.
- If you subclass HCInvocationMatcher for a custom matcher, the ivars have been renamed.
- If you import HCCollectMatchers.h for a custom matcher, change this to import HCCollect.h.
- HCTestFailureHandler has changed from a protocol to a class.

Also, if you're not using CocoaPods, specify `-ObjC` in your "Other Linker Flags".


Version 3.0.1
-------------
_29 Oct 2013_

**Fixes:**

- Fixed problem where isNot did not ask the sub-matcher's mismatch description. _Thanks to: James
  Richard and Jonathan Barnes_
- Fixed crash in `describedAs` matcher . _Thanks to: Nikolaj Schumacher_
- Fixed crash in `hasProperty` matcher when the property is a primitive type. _Thanks to: Nikolaj
  Schumacher_

**Improvements:**

- Changed matcher factory methods to return plain `id` so that matchers can be used without casting
  to `(id)` for OCMockito arguments.
- Added support for 64-bit iOS devices.

**Examples & Documentation:**

- Updated examples so they are based on Apple's templates for main target vs. test target. Added
  CocoaPods examples.
- Eliminated DocSet. Documentation will be in the main README and in the OCHamcrest wiki,
  https://github.com/hamcrest/OCHamcrest/wiki/_pages


Version 3.0.0
-------------
_06 Sep 2013_

**Features:**

- Added support for XCTest. _Special thanks to Jiajun "gaosboy" for pointing the way, and to Richard
  Clem for testing._
- Made unit test integration more flexible with HC_testFailureHandlerChain. It can be called from
  outside OCHamcrest to signal a test failure within the current testing framework. (At present it
  tries XCTest, then SenTestCase, then falls back on raising a generic exception.)
    
**Deleted:**

- HCRequireNonNilString.h (deprecated in v1.2)
- `empty` matcher (deprecated in v2.1.0)


Version 2.1.0
-------------
_23 Jun 2013_

**Fixes:**

- Made build script flexible so that doxygen isn't required, or can be in a different location.
  _Thanks to: Bennett Smith_
- Fixed problem formatting percent symbols in assertion failures. _Thanks to: Nikolaj Schumacher_
- Fixed wrong descriptions in the unordered collection matcher. _Thanks to: Nikolaj Schumacher_
- Fixed underlying cause of crash in Mac version on assertion failure. With this fix, we could switch
  back to optimized code. _Thanks to: Nikolaj Schumacher_
- Fixed MacExample so it finds OCHamcrest.

**Features:**

- Added support for XCTest. (This was undone by subsequent updates to XCTest.)

**Deprecated:**

- `empty` clashed with the C++ string method of the same name. It has been renamed to `isEmpty`.

**Project changes:**

- Increased deployment targets to Mac OS X 10.7, iOS 5.0.


Version 2.0.1
-------------
_12 May 2013_

**Fixes:**

- Fixed crash in Mac version on assertion failure. (Problem with optimized code)
- Fixed crash in `instanceOf` and `isA` when argument was `nil`.

**Improvements:**

- Updated example projects to Xcode 4.6.


Version 2.0.0
-------------
_13 Apr 2013_

This release adopts Semantic Versioning (http://semver.org). Since removal of deprecated items is a
backwards incompatible change, the major version number is incremented. _Thanks to: Jens Nerup_

**Fixes:**

- Fixed GTM compatibility -- avoid shadowing `conformsToProtocol:`

**New matchers:**

- `isA` matches objects that are instances of a given class, but not of any subclass.

**Improved matchers:**

- `equalToBool` has a better description. _Thanks to: Jonathan Crooke_
- `instanceOf` mismatch description now includes actual class.

**Deleted following items deprecated in v1.8:**

- C++ template function `boxNumber`
- `HC_conformsToProtocol` (which was renamed to `HC_conformsTo`)

**Project changes:**

- Updated project settings to Xcode 4.6. _Thanks to: Florian Buerger_
- Fixed unit tests so they remain quiet when handling expected test failures.
- Replaced older code coverage scripts with XcodeCoverage submodule.


Version 1.9
-----------
_23 Nov 2012_

**Improved matchers:**

- Changed `hasCount` / `hasCountOf` mismatch description so that count comes first (if object
  has a count).

**Project changes:**

- Fixed warnings revealed by latest Xcode. _Thanks to: David Hart_
- Changed iOS Architecture support to "Standard" (which includes armv7s)
- Changed Mac Architecture support to 64-bit only
- Converted source, tests, and examples to ARC


Version 1.8
-----------
_09 Jul 2012_

The primary purpose of this release is to make it easier to add OCHamcrest to iOS projects. No more
need to specify "Other Linker Flags"! Depending on your project, you may be able to eliminate:

  * `-lstdc++`
  * `-ObjC`

Also, the repository has a new official home: https://github.com/hamcrest/OCHamcrest/

**No need to specify "Other Linker Flags" in iOS projects:**

- Changed all Objective-C++ to Objective-C
- Eliminated categories

**Deprecated:**

- C++ template function `boxNumber`.
- `conformsToProtocol` clashed with the method of the same name. It has been renamed to
  `conformsTo`.

**Deleted following items deprecated in v1.2:**

- `-[HCDescription appendValue]`
- `+[HCInvocationMatcher createInvocationForSelector:onClass:]`
- NSObject+SelfDescribingValue


Version 1.7
-----------
_20 Feb 2012_

**New matchers:**

- `conformsToProtocol` matches objects that conform to a given protocol. _Thanks to: Todd Farrell_

**Improved matchers:**

- `hasProperty` now works for methods with primitive return types. _Thanks to: Christopher
  Pickslay_

**Other improvements:**

- Rewrote introductory sections of documentation.


Version 1.6
-----------
_27 Sep 2011_

**Fixes:**

- `stringContainsInOrder` was missing from the master header; now it's there.

**New matchers:**

- `hasProperty` matches the return value of a method with a given name. (It could be a property,
  but really can be any method with no arguments that returns an object.) _Thanks to: Justin
  Shacklette_

**Improvements:**

- Rewrote documentation.
- Matchers that require a nil-terminated list now generate a compiler error if you don't have
  `nil` at the end.


Version 1.5
-----------
_29 Apr 2011_

**Fixes:**

- Fixed crash when trying to describe an object with `nil` description.

**Packaging:**

- Updated project to Xcode 4. iOS framework / documentation / distribution scripts are now external,
  run from command-line instead of Xcode.
- Improved documentation by adding Factory headings pointing from implementing classes back to their
  factories.

**New matcher:**

- `stringContainsInOrder` matches string containing given list of substrings, in order.

**Improved matchers:**

- Changed `sameInstance` mismatch description to omit address when describing `nil`.
- For consistency, changed `anyOf` and `allOf` to implicitly wrap non-matcher values in
  `equalTo`.


Version 1.4
-----------
_13 Feb 2011_

**New matchers:**

- `hasEntries` matches dictionary containing key-value pairs satisfying a given list of
  alternating keys and value matchers.

**Improvements:**

- Added complete descriptions to macros so they appear in Xcode 4 Quick Help. (Couldn't add
  arguments to macros without breaking backwards compatibility.)

**Improved descriptions:**

- Improved description of `hasEntry`, removing colon so it doesn't get truncated in Xcode's error
  display.
- `is` no longer says "is ..." in its description, but just lets the inner description pass
  through.
- Consistently use articles to begin descriptions, such as "a dictionary containing" instead of
  "dictionary containing".


Version 1.3
-----------
_05 Jan 2011_

**Improved descriptions:**

- Fixed `contains` and `containsInAnyOrder` to describe mismatch if item is not a collection.
- Fixed `describedAs` and `is` to use their nested matchers to generate mismatch descriptions.
- `sameInstance` is more readable, and includes object memory addresses.
- If object has a count, `hasCount` mismatch describes actual count.
- Don't wrap angle brackets around a description that already has them.
- Improved readability of several matchers.

**Other improvements:**

- `instanceOf` now guards against `nil` being passed as the expected type.


Version 1.2
-----------
_03 Jan 2011_

**Fixes:**

- Fixed assertThat to describe the diagnosis of the mismatch, not just the mismatched value.

**New matchers:**

- `hasCount` matches collections for which `-count` satisfies a given matcher.
- `hasCountOf` matches collections for which `-count` equals a given count.
- `empty` matches empty collection.

**Improvements:**

- Expanded helper class HCInvocationMatcher:
  * New property `shortMismatchDescription` determines whether mismatch description is short or
    long. Default is long description.
  * New method `-invokeOn:` invokes stored invocation on given item.
- Since `nil` cannot be directly stored in collections, collection matchers now guard against
  `nil`.
- Expanded BaseDescription's `-appendDescriptionOf:` to handle all types of values, not just
  self-describing values.

**Deprecated:**

- Description's `-appendValue:` no longer needed; call `-appendDescriptionOf:` instead. This
  also means NSObject+SelfDescribingValue is no longer needed.
- Renamed HCInvocation's helper class method `+createInvocationForSelector:onClass:` to
  `+invocationForSelector:onClass:`
- New helper function `HCRequireNonNilObject` should be used in place of
  `HCRequireNonNilString`.


Version 1.1.2
-------------
_28 Dec 2010_

**Fixes:**

- Fixed crash that occurred when trying to describe the matchers `allOf`, `anyOf` and `isIn`
  on iOS. Related to `-ObjC` linker flag.
- Fix problems introduced in broken release v1.1:
  * Added the new matchers to the master header and to the iOS target.
  * Fixed distribution zip file to preserve symlinks in frameworks.

**New matchers:**

- `contains` matches collections with matching items in order.
- `containsInAnyOrder` matches collections with matching items in any order.

**Improvements:**

- Changed documentation from HTML to Xcode documentation set. Run `make install` from the
  Documentation folder to install.
- Rearranged documentation modules to make things easier to find.
- Changed convenience methods to invoke superclass and return `id`, to support possibility of
  subclassing matchers.


Version 1.0
-----------
_26 Oct 2010_

First official release, including:

* Documentation
* Examples for
  - Cocoa
  - iOS
  - Creating a custom matcher


Before v1.0
-----------

_07 Oct 2010_

* For iOS: Added OCHamcrestIOS.framework target which provides release builds for both simulator and
  device into a single framework. Yes, a framework that can be used for iOS development without
  requiring users to mess with header search paths and link settings. Simply drop the framework into
  your project and `#import <OCHamcrestIOS/OCHamcrestIOS.h>` _Thanks to: Aaron Jacobs_

_06 Oct 2010_

* Work around bug in iPhone simulator that causes a test failure to terminate the app. _Thanks to:
  Aaron Jacobs_

_06 Sep 2010_

* Added static library target and changes for iOS.

_01 Dec 2009_

* Added `assertThat___` and `equalTo___` for all types understood by NSNumber. For example:  
  `assertThatInt(42, equalToInt(42))`

_24 Nov 2009_

* Changed `assertThat` behavior to work more seamlessly with OCUnit: Instead of throwing an
  exception, it calls the same method as OCUnit's assertion macros to fail the test. As a result, a
  failing `assertThat` will not terminate the test, so that the test can record other failures.
  (Following normal OCUnit behavior, you can instruct the test case to terminate at the first
  failure by invoking `raiseAfterFailure`.)  
  This change requires that `assertThat` be called only within subclasses of SenTestCase, which
  wasn't the case before. You will need to recompile your tests.  
  If you need an original-style assertion that can be called outside of a SenTestCase, email your
  request to hamcrest-dev@googlegroups.com

_24 Nov 2009_

* Support Xcode 3.2's redesigned Build Results window by removing colons from `assertThat`
  description.

_17 Oct 2009_

* Added helper class HCInvocationMatcher for building other matchers from NSInvocations. See
  HCHasDescription for an example.

_11 Aug 2009_

* Renamed framework to OCHamcrest.

_07 Jul 2009_

* Added support for Mac OS X 10.4 projects.

_28 Jan 2009_

* Fixed compiler errors when used with Objective-C++ (.mm files).

_24 Jan 2009_

* Added means for matchers to describe mismatches. You can use either
  `matches:describingMismatchTo:` to do it one shot, or call `describeMismatchOf:To:` once you
  know a particular item does not match.

_18 Jul 2008_

* Changed matchers whose description looks similar to a function call so that the description
  matches the name of the factory function.

_13 Apr 2008_

* Initial release
