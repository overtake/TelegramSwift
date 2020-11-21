//
//  SwiftHelpersTests.swift
//  OHHTTPStubs
//
//  Created by Olivier Halligon on 20/09/2015.
//  Copyright © 2015 AliSoftware. All rights reserved.
//

import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import OHHTTPStubsSwift
@testable import OHHTTPStubs
#else
@testable import OHHTTPStubs
#endif

#if swift(>=3.0)
#else
#if swift(>=2.2)
    extension SequenceType {
        private func enumerated() -> EnumerateSequence<Self> {
            return enumerate()
        }
    }

    extension NSMutableURLRequest {
        override var httpMethod: String? {
            get {
                return HTTPMethod
            }
            set(method) {
                self.HTTPMethod = method!
            }
        }
    }
#endif
#endif

class SwiftHelpersTests : XCTestCase {

  func testHTTPMethod() {
    let methods = ["GET", "PUT", "PATCH", "POST", "DELETE", "HEAD", "FOO"]
    let matchers = [isMethodGET(), isMethodPUT(), isMethodPATCH(), isMethodPOST(), isMethodDELETE(), isMethodHEAD()]

    for (idxMethod, method) in methods.enumerated() {
#if swift(>=3.0)
      var req = URLRequest(url: URL(string: "foo://bar")!)
#else
      let req = NSMutableURLRequest(URL: NSURL(string: "foo://bar")!)
#endif
      req.httpMethod = method
      for (idxMatcher, matcher) in matchers.enumerated() {
        let expected = idxMethod == idxMatcher // expect to be true only if indexes match
        XCTAssert(matcher(req) == expected, "Function is\(methods[idxMatcher])() failed to test request with HTTP method \(method).")
      }
    }
  }

  func testIsAbsoluteURLString() {
    let matcher = isAbsoluteURLString("foo://foo/bar?param1=123&param2=foo#anchor")

    let urls = [
      "foo:": false,
      "foo://foo/bar/baz": false,
      "foo://foo/bar?param1=123&param2=foo#anchor": true,
      "foo://foo/bar?param1=123&param2=foo": false,
      "foo://foo/bar?param1=123": false,
      "foo://foo/bar": false,
      "bar://foo/bar": false,
      "bar://foo/ba": false,
      "foobar://": false
    ]

    for (url, result) in urls {
      #if swift(>=3.0)
        let req = URLRequest(url: URL(string: url)!)
      #else
        let req = NSURLRequest(URL: NSURL(string: url)!)
      #endif
      XCTAssert(matcher(req) == result, "isAbsoluteURLString(\"foo://foo/bar?param1=123&param2=foo#anchor\") matcher failed when testing url \(url)")
    }
  }

  func testIsScheme() {
    let matcher = isScheme("foo")

    let urls = [
      "foo:": true,
      "foo://": true,
      "foo://bar/baz": true,
      "bar://": false,
      "bar://foo/": false,
      "foobar://": false
    ]

    for (url, result) in urls {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      XCTAssert(matcher(req) == result, "isScheme(\"foo\") matcher failed when testing url \(url)")
    }
  }

  func testIsHost() {
    let matcher = isHost("foo")

    let urls = [
      "foo:": false,
      "foo://": false,
      "foo://bar/baz": false,
      "bar://foo": true,
      "bar://foo/baz": true,
    ]

    for (url, result) in urls {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      XCTAssert(matcher(req) == result, "isHost(\"foo\") matcher failed when testing url \(url)")
    }
  }

#if swift(>=3.0)
  private let isSwift3 = true
#else
  private let isSwift3 = false
#endif

  func testIsPath_absoluteURL() {
    testIsPath("/foo/bar/baz", isAbsoluteMatcher: true)
  }

  func testIsPath_relativeURL() {
    testIsPath("foo/bar/baz", isAbsoluteMatcher: false)
  }

  func testIsPath(_ path: String, isAbsoluteMatcher: Bool) {
    let matcher = isPath(path)
    // In Swift 2.3 and before, NSURL was not bridged to the URL value type in Swift
    // And it happens that NSURL.path (Swift 2.2) does NOT contain the ";" (and string after) if any
    // While URL.path (Swift 2.3/3.0) DOES contain the ";" (and the string after), if any

    let urls = [
      // Absolute URLs
      "scheme:": false,
      "scheme://": false,
      "scheme://foo/bar/baz": false,
      "scheme://host/foo/bar": false,
      "scheme://host/foo/bar/baz": isAbsoluteMatcher,
      "scheme://host/foo/bar/baz?q=1": isAbsoluteMatcher,
      "scheme://host/foo/bar/baz#anchor": isAbsoluteMatcher,
      "scheme://host/foo/bar/baz;param": isAbsoluteMatcher && !isSwift3,
      "scheme://host/foo/bar/baz/wizz": false,
      "scheme://host/path#/foo/bar/baz": false,
      "scheme://host/path?/foo/bar/baz": false,
      "scheme://host/path;/foo/bar/baz": false,
      // Relative URLs
      "foo/bar/baz": !isAbsoluteMatcher,
      "foo/bar/baz?q=1": !isAbsoluteMatcher,
      "foo/bar/baz#anchor": !isAbsoluteMatcher,
      "foo/bar/baz;param": !isAbsoluteMatcher && !isSwift3,
      "foo/bar/baz/wizz": false,
      "path#/foo/bar/baz": false,
      "path?/foo/bar/baz": false,
      "path;/foo/bar/baz": false,
    ]

    for (url, result) in urls {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      let p = req.url?.path
      print("URL: \(url) -> Path: \(String(reflecting: p))")
      XCTAssert(matcher(req) == result, "isPath(\"\(path)\") matcher failed when testing url \(url)")
    }
  }

  func testPathStartsWith_absoluteURL() {
    testPathStartsWith("/foo/bar", isAbsoluteMatcher: true)
  }

  func testPathStartsWith_relativeURL() {
    testPathStartsWith("foo/bar", isAbsoluteMatcher: false)
  }

  private func testPathStartsWith(_ path: String, isAbsoluteMatcher: Bool) {
    let matcher = pathStartsWith(path)

    let urls = [
      // Absolute URLs
      "scheme:": false,
      "scheme://": false,
      "scheme://foo/bar/baz": false,
      "scheme://host/foo/bar": isAbsoluteMatcher,
      "scheme://host/foo/bar/baz": isAbsoluteMatcher,
      "scheme://host/foo/bar?q=1": isAbsoluteMatcher,
      "scheme://host/foo/bar#anchor": isAbsoluteMatcher,
      "scheme://host/foo/bar;param": isAbsoluteMatcher,
      "scheme://host/path/foo/bar/baz": false,
      "scheme://host/path#/foo/bar/baz": false,
      "scheme://host/path?/foo/bar/baz": false,
      "scheme://host/path;/foo/bar/baz": false,
      // Relative URLs
      "foo/bar": !isAbsoluteMatcher,
      "foo/bar/baz": !isAbsoluteMatcher,
      "foo/bar?q=1": !isAbsoluteMatcher,
      "foo/bar#anchor": !isAbsoluteMatcher,
      "foo/bar;param": !isAbsoluteMatcher,
      "path/foo/bar/baz": false,
      "path#/foo/bar/baz": false,
      "path?/foo/bar/baz": false,
      "path;/foo/bar/baz": false,
    ]

    for (url, result) in urls {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      let p = req.url?.path
      print("URL: \(url) -> Path: \(String(reflecting: p))")
      XCTAssert(matcher(req) == result, "pathStartsWith(\"\(path)\") matcher failed when testing url \(url)")
    }
  }

  func testPathEndsWith() {
    let path = "/bar"
    let matcher = pathEndsWith(path)

    let urls = [
      // Absolute URLs
      "scheme:": false,
      "scheme://": false,
      "scheme://foo/bar/baz": false,
      "scheme://host/foo/bar": true,
      "scheme://host/foo/bar/baz": false,
      "scheme://host/foo/bar?q=1": true,
      "scheme://host/foo/bar#anchor": true,
      "scheme://host/foo/bar;param": !isSwift3,
      "scheme://host/path/foo/bar/baz": false,
      "scheme://host/path#/foo/bar": false,
      "scheme://host/path?/foo/bar": false,
      "scheme://host/path;/foo/bar": isSwift3,
      // Relative URLs
      "foo/bar": true,
      "foo/bar/baz": false,
      "foo/bar?q=1": true,
      "foo/bar#anchor": true,
      "foo/bar;param": !isSwift3,
      "path/foo/bar/baz": false,
      "path#/foo/bar": false,
      "path?/foo/bar": false,
      "path;/foo/bar": isSwift3,
      ]

    for (url, result) in urls {
      #if swift(>=3.0)
        let req = URLRequest(url: URL(string: url)!)
      #else
        let req = NSURLRequest(URL: NSURL(string: url)!)
      #endif
      let p = req.url?.path
      print("URL: \(url) -> Path: \(String(reflecting: p))")
      XCTAssert(matcher(req) == result, "pathEndsWith(\"\(path)\") matcher failed when testing url \(url)")
    }
  }

  func testPathMatches_caseSensitive() {
    testPathMatches("/bar/[0-9]+/baz$", caseInsensitive: false)
  }

  func testPathMatches_casensensitive() {
    testPathMatches("/bar/[0-9]+/baz$", caseInsensitive: true)
  }

  private func testPathMatches(_ regexString: String, caseInsensitive: Bool) {
    #if swift(>=3.0)
      let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    #else
      let options: NSRegularExpressionOptions = caseInsensitive ? .CaseInsensitive : []
    #endif
    let matcher = pathMatches(regexString, options: options)

    let urls = [
      // Case sensitive
      "scheme://foo/bar/12/baz": true,
      "scheme://host/foo/bar/12": false,
      "scheme://host/foo/bar/12/baz?q=1": true,
      "scheme://host/foo/bar/12/baz#anchor": true,
      "scheme://host/foo/bar/12/baz;param": !isSwift3,
      "scheme://host/path/foo/bar/12/baz": true,
      "scheme://host/path#/foo/bar/12/baz": false,
      "scheme://host/path?/foo/bar/12/baz": false,
      "scheme://host/path;/foo/bar/12/baz": isSwift3,
      // Case insensitive
      "scheme://host/foo/bAr/12/baZ?q=1": caseInsensitive,
      "scheme://host/foo/bAr/12/baZ#anchor": caseInsensitive,
      "scheme://host/foo/bAr/12/baZ;param": caseInsensitive && !isSwift3,
      "scheme://host/path/foo/bAr/12/baZ": caseInsensitive,
      "scheme://host/path#/foo/bAr/12/baZ": false,
      "scheme://host/path?/foo/bAr/12/baZ": false,
      "scheme://host/path;/foo/bAr/12/baZ": caseInsensitive && isSwift3,
      ]

    for (url, result) in urls {
      #if swift(>=3.0)
        let req = URLRequest(url: URL(string: url)!)
      #else
        let req = NSURLRequest(URL: NSURL(string: url)!)
      #endif
      let p = req.url?.path
      print("URL: \(url) -> Path: \(String(reflecting: p))")
      XCTAssert(matcher(req) == result, "pathMatches(\"\(regexString)\"\(caseInsensitive ? "i" : "")) matcher failed when testing url \(url)")
    }
  }

  func testIsExtension() {
    let matcher = isExtension("txt")

    let urls = [
      "txt:": false,
      "txt://": false,
      "txt://txt/txt/txt": false,
      "scheme://host/foo/bar.png": false,
      "scheme://host/foo/bar.txt": true,
      "scheme://host/foo/bar.txt?q=1": true,
      "scheme://host/foo/bar.baz?q=wizz.txt": false,
    ]

    for (url, result) in urls {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      XCTAssert(matcher(req) == result, "isExtension(\"txt\") matcher failed when testing url \(url)")
    }

  }
  @available(iOS 8.0, OSX 10.10, *)
  func testContainsQueryParams() {
    let params: [String: String?] = ["q":"test", "lang":"en", "empty":"", "flag":nil]
    let matcher = containsQueryParams(params)

    let urls = [
      "foo://bar": false,
      "foo://bar?q=test": false,
      "foo://bar?lang=en": false,
      "foo://bar#q=test&lang=en&empty=&flag": false,
      "foo://bar#lang=en&empty=&flag&q=test": false,
      "foo://bar;q=test&lang=en&empty=&flag": false,
      "foo://bar;lang=en&empty=&flag&q=test": false,

      "foo://bar?q=test&lang=en&empty=&flag": true,
      "foo://bar?lang=en&flag&empty=&q=test": true,
      "foo://bar?q=test&lang=en&empty=&flag#anchor": true,
      "foo://bar?q=test&lang=en&empty&flag": false, // key "empty" with no value is matched against nil, not ""
      "foo://bar?q=test&lang=en&empty=&flag=": false, // key "flag" with empty value is matched against "", not nil
      "foo://bar?q=en&lang=test&empty=&flag": false, // param keys and values mismatch
      "foo://bar?q=test&lang=en&empty=&flag&&wizz=fuzz": true,
      "foo://bar?wizz=fuzz&empty=&lang=en&flag&&q=test": true,
      "?q=test&lang=en&empty=&flag": true,
      "?lang=en&flag&empty=&q=test": true,
    ]

    for (url, result) in urls {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif

      XCTAssert(matcher(req) == result, "containsQueryParams(\"\(params)\") matcher failed when testing url \(url)")
    }
  }

  func testHasHeaderNamedIsTrue() {
#if swift(>=3.0)
    var req = URLRequest(url: URL(string: "foo://bar")!)
#else
    let req = NSMutableURLRequest(URL: NSURL(string: "foo://bar")!)
#endif
    req.addValue("1234567890", forHTTPHeaderField: "ArbitraryKey")

    let hasHeader = hasHeaderNamed("ArbitraryKey")(req)

    XCTAssertTrue(hasHeader)
  }

  func testHasHeaderNamedIsFalse() {
#if swift(>=3.0)
    let req = URLRequest(url: URL(string: "foo://bar")!)
#else
    let req = NSURLRequest(URL: NSURL(string: "foo://bar")!)
#endif

    let hasHeader = hasHeaderNamed("ArbitraryKey")(req)

    XCTAssertFalse(hasHeader)
  }

  func testHeaderValueForKeyEqualsIsTrue() {
#if swift(>=3.0)
    var req = URLRequest(url: URL(string: "foo://bar")!)
#else
    let req = NSMutableURLRequest(URL: NSURL(string: "foo://bar")!)
#endif
    req.addValue("bar", forHTTPHeaderField: "foo")

    let matchesHeader = hasHeaderNamed("foo", value: "bar")(req)

    XCTAssertTrue(matchesHeader)
  }

  func testHeaderValueForKeyEqualsIsFalse() {
#if swift(>=3.0)
    var req = URLRequest(url: URL(string: "foo://bar")!)
#else
    let req = NSMutableURLRequest(URL: NSURL(string: "foo://bar")!)
#endif
    req.addValue("bar", forHTTPHeaderField: "foo")

    let matchesHeader = hasHeaderNamed("foo", value: "baz")(req)

    XCTAssertFalse(matchesHeader)
  }

  func testHeaderValueForKeyEqualsDoesNotExist() {
#if swift(>=3.0)
    let req = URLRequest(url: URL(string: "foo://bar")!)
#else
    let req = NSURLRequest(URL: NSURL(string: "foo://bar")!)
#endif

    let matchesHeader = hasHeaderNamed("foo", value: "baz")(req)

    XCTAssertFalse(matchesHeader)
  }
    
  func test_ohhttpStubs_httpBody() {
#if swift(>=3.0)
    let data = "Hello world".data(using: .utf8)
    var req = URLRequest(url: URL(string: "foo://bar")!)
    req.httpBody = data
    XCTAssertEqual(req.ohhttpStubs_httpBody, data)
#else
    let data = "Hello world".dataUsingEncoding(NSUTF8StringEncoding)
    let req = NSMutableURLRequest(URL: NSURL(string: "foo://bar")!)
    req.HTTPBody = data
    XCTAssertEqual(req.OHHTTPStubs_HTTPBody(), data)
#endif
  }

#if swift(>=3.0)
  func testHasJsonBodyIsTrue() {
    let jsonStringsAndObjects = [
      // Exact match
      ("{ \"foo\": \"bar\", \"baz\": 42, \"qux\": true }",
       ["foo": "bar", "baz": 42, "qux": true]),
      // Changed attribute order
      ("{ \"qux\": true, \"foo\": \"bar\", \"baz\": 42 }",
       ["foo": "bar", "baz": 42, "qux": true]),
      // Newlines and indentations
      ("{ \"foo\": \"bar\", \n\"baz\": 42,     \"qux\": true }",
       ["foo": "bar", "baz": 42, "qux": true]),
      // Nested objects
      ("{ \"foo\": \"bar\", \"baz\": { \"qux\": true, \"quux\": [\"spam\", \"ham\", \"eggs\"] } }",
       ["foo": "bar", "baz": ["qux": true, "quux": ["spam", "ham", "eggs"]]]),
      // Nested objects with changed attribute order
      ("{ \"foo\": \"bar\", \"baz\": { \"quux\": [\"spam\", \"ham\", \"eggs\"], \"qux\": true } }",
       ["foo": "bar", "baz": ["qux": true, "quux": ["spam", "ham", "eggs"]]]),
    ]
    
    for (jsonString, expectedJsonObject) in jsonStringsAndObjects {
      var req = URLRequest(url: URL(string: "foo://bar")!)
      req.httpBody = jsonString.data(using: .utf8)
      let matchesJsonBody = hasJsonBody(expectedJsonObject)(req)
      
      XCTAssertTrue(matchesJsonBody)
    }
  }
#endif

#if swift(>=3.0)
  func testHasJsonBodyIsFalse() {
    let jsonStringsAndObjects = [
      // Changed value
      ("{ \"foo\": \"bar\" }",
       ["foo": "qux"]),
      // Changed key
      ("{ \"foo\": \"bar\" }",
       ["baz": "bar"]),
      // Missing attribute
      ("{ \"foo\": \"bar\", \"baz\": 42 }",
       ["foo": "bar"]),
      // Extraneous attribute
      ("{ \"foo\": \"bar\" }",
       ["foo": "bar", "baz": 42]),
      // Changed order in array
      ("{ \"foo\": [\"spam\", \"ham\", \"eggs\"] }",
       ["foo": ["spam", "eggs", "ham"]]),
      // Nested objects with changed value
        ("{ \"foo\": \"bar\", \"baz\": { \"qux\": true } }",
       ["foo": "bar", "baz": ["qux": false]])
    ]
    
    for (jsonString, expectedJsonObject) in jsonStringsAndObjects {
      var req = URLRequest(url: URL(string: "foo://bar")!)
      req.httpBody = jsonString.data(using: .utf8)
      let matchesJsonBody = hasJsonBody(expectedJsonObject)(req)
      
      XCTAssertFalse(matchesJsonBody)
    }
  }
#endif

#if swift(>=3.0)
  @available(iOS 8.0, OSX 10.10, *)
  func testHasFormBodyIsTrue() {
    func assertMatchesFormBody(_ formBody: String, _ expectedKeyValues: [String: String?], file: StaticString = #file, line: UInt = #line) {
        var req = URLRequest(url: URL(string: "foo://bar")!)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody.data(using: .utf8)
        XCTAssertTrue(hasFormBody(expectedKeyValues)(req), file: file, line: line)
    }

    // Exact match
    assertMatchesFormBody("foo=bar&baz=42&qux=true", ["foo": "bar", "baz": "42", "qux": "true"])
    // Changed attribute order
    assertMatchesFormBody("qux=true&foo=bar&baz=42", ["foo": "bar", "baz": "42", "qux": "true"])
    // Contains key with no value
    assertMatchesFormBody("foo=bar&baz&qux=42", ["foo": "bar", "baz": nil, "qux": "42"])
    // Contains key with empty value
    assertMatchesFormBody("foo=bar&baz=&qux=42", ["foo": "bar", "baz": "", "qux": "42"])
    // Contains escaped character
    assertMatchesFormBody("foo=bar%40baz", ["foo": "bar@baz"])
  }
#endif

#if swift(>=3.0)
  @available(iOS 8.0, OSX 10.10, *)
  func testHasFormBodyIsFalse() {
    func assertNotMatchesFormBody(_ formBody: String, _ expectedKeyValues: [String: String?], file: StaticString = #file, line: UInt = #line) {
        var req = URLRequest(url: URL(string: "foo://bar")!)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody.data(using: .utf8)
        XCTAssertFalse(hasFormBody(expectedKeyValues)(req), file: file, line: line)
    }
    // Changed value
    assertNotMatchesFormBody("foo=bar&baz=40", ["foo": "bar", "baz": "42"])
    // Changed key
    assertNotMatchesFormBody("foo=bar&qux=42", ["foo": "bar", "baz": "42"])
    // Missing attribute
    assertNotMatchesFormBody("foo=bar&baz=42&qux=true", ["foo": "bar", "baz": "42"])
    // Extraneous attribute
    assertNotMatchesFormBody("foo=bar&baz=42", ["foo": "bar", "baz": "42", "qux": "true"])
    // Missing value
    assertNotMatchesFormBody("foo=&bar=baz", ["foo": nil, "bar": "baz"])
    // Extraneous value
    assertNotMatchesFormBody("foo&bar=baz", ["foo": "", "baz": "42"])
  }
#endif

  let sampleURLs = [
    // Absolute URLs
    "scheme:",
    "scheme://",
    "scheme://foo/bar/baz",
    "scheme://host/foo/bar",
    "scheme://host/foo/bar/baz",
    "scheme://host/foo/bar/baz?q=1",
    "scheme://host/foo/bar/baz#anchor",
    "scheme://host/foo/bar/baz;param",
    "scheme://host/foo/bar/baz/wizz",
    "scheme://host/path#/foo/bar/baz",
    "scheme://host/path?/foo/bar/baz",
    "scheme://host/path;/foo/bar/baz",
    // Relative URLs
    "foo/bar/baz",
    "foo/bar/baz?q=1",
    "foo/bar/baz#anchor",
    "foo/bar/baz;param",
    "foo/bar/baz/wizz",
    "path#/foo/bar/baz",
    "path?/foo/bar/baz",
    "path;/foo/bar/baz"
  ]

  let trueMatcher: HTTPStubsTestBlock = { _ in return true }
  let falseMatcher: HTTPStubsTestBlock = { _ in return false }

  func testOrOperator() {
    for url in sampleURLs {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      XCTAssert((trueMatcher || trueMatcher)(req) == true, "trueMatcher || trueMatcher should result in a trueMatcher")
      XCTAssert((trueMatcher || falseMatcher)(req) == true, "trueMatcher || falseMatcher should result in a trueMatcher")
      XCTAssert((falseMatcher || trueMatcher)(req) == true, "falseMatcher || trueMatcher should result in a trueMatcher")
      XCTAssert((falseMatcher || falseMatcher)(req) == false, "falseMatcher || falseMatcher should result in a falseMatcher")
    }
  }

  func testAndOperator() {
    for url in sampleURLs {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      XCTAssert((trueMatcher && trueMatcher)(req) == true, "trueMatcher && trueMatcher should result in a trueMatcher")
      XCTAssert((trueMatcher && falseMatcher)(req) == false, "trueMatcher && falseMatcher should result in a falseMatcher")
      XCTAssert((falseMatcher && trueMatcher)(req) == false, "falseMatcher && trueMatcher should result in a falseMatcher")
      XCTAssert((falseMatcher && falseMatcher)(req) == false, "falseMatcher && falseMatcher should result in a falseMatcher")
    }
  }

  func testNotOperator() {
    for url in sampleURLs {
#if swift(>=3.0)
      let req = URLRequest(url: URL(string: url)!)
#else
      let req = NSURLRequest(URL: NSURL(string: url)!)
#endif
      XCTAssert((!trueMatcher)(req) == false, "!trueMatcher should result in a falseMatcher")
      XCTAssert((!falseMatcher)(req) == true, "!falseMatcher should result in a trueMatcher")
    }
  }
}
