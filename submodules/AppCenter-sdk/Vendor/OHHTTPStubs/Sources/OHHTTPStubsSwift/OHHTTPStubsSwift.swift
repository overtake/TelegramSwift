/***********************************************************************************
 *
 * Copyright (c) 2012 Olivier Halligon
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/

/**
 * Swift Helpers
 */

import Foundation
#if SWIFT_PACKAGE
import OHHTTPStubs
#endif

#if !swift(>=3.0)
  extension HTTPStubs {
    private class func stubRequests(passingTest: HTTPStubsTestBlock, withStubResponse: HTTPStubsResponseBlock) -> HTTPStubsDescriptor {
      return stubRequestsPassingTest(passingTest, withStubResponse: withStubResponse)
    }
  }

  extension NSURLRequest {
    var httpMethod: String? { return HTTPMethod }
    var url: NSURL? { return URL }
  }

  extension NSURLComponents {
    private convenience init?(url: NSURL, resolvingAgainstBaseURL: Bool) {
      self.init(URL: url, resolvingAgainstBaseURL: resolvingAgainstBaseURL)
    }
  }

  private typealias URLRequest = NSURLRequest

  extension URLRequest {
    private func value(forHTTPHeaderField key: String) -> String? {
      return valueForHTTPHeaderField(key)
    }
  }

  extension String {
    private func contains(string: String) -> Bool {
      return rangeOfString(string) != nil
    }
  }
#else
  extension URLRequest {
    public var ohhttpStubs_httpBody: Data? {
      return (self as NSURLRequest).ohhttpStubs_HTTPBody()
    }
  }
#endif


// MARK: Syntaxic Sugar for OHHTTPStubs

/**
 * Helper to return a `HTTPStubsResponse` given a fixture path, status code and optional headers.
 *
 * - Parameter filePath: the path of the file fixture to use for the response
 * - Parameter status: the status code to use for the response
 * - Parameter headers: the HTTP headers to use for the response
 *
 * - Returns: The `HTTPStubsResponse` instance that will stub with the given status code
 *            & headers, and use the file content as the response body.
 */
#if swift(>=3.0)
  public func fixture(filePath: String, status: Int32 = 200, headers: [AnyHashable: Any]?) -> HTTPStubsResponse {
    return HTTPStubsResponse(fileAtPath: filePath, statusCode: status, headers: headers)
  }
#else
  public func fixture(filePath: String, status: Int32 = 200, headers: [NSObject: AnyObject]?) -> HTTPStubsResponse {
  return HTTPStubsResponse(fileAtPath: filePath, statusCode: status, headers: headers)
  }
#endif

/**
 * Helper to call the stubbing function in a more concise way?
 *
 * - Parameter condition: the matcher block that determine if the request will be stubbed
 * - Parameter response: the stub reponse to use if the request is stubbed
 *
 * - Returns: The opaque `HTTPStubsDescriptor` that uniquely identifies the stub
 *            and can be later used to remove it with `removeStub:`
 */
#if swift(>=3.0)
  @discardableResult
  public func stub(condition: @escaping HTTPStubsTestBlock, response: @escaping HTTPStubsResponseBlock) -> HTTPStubsDescriptor {
    return HTTPStubs.stubRequests(passingTest: condition, withStubResponse: response)
  }
#else
  public func stub(condition: HTTPStubsTestBlock, response: HTTPStubsResponseBlock) -> HTTPStubsDescriptor {
  return HTTPStubs.stubRequests(passingTest: condition, withStubResponse: response)
  }
#endif



// MARK: Create HTTPStubsTestBlock matchers

/**
 * Matcher testing that the `NSURLRequest` is using the **GET** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the GET method
 */
public func isMethodGET() -> HTTPStubsTestBlock {
  return { $0.httpMethod == "GET" }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **POST** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the POST method
 */
public func isMethodPOST() -> HTTPStubsTestBlock {
  return { $0.httpMethod == "POST" }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **PUT** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the PUT method
 */
public func isMethodPUT() -> HTTPStubsTestBlock {
  return { $0.httpMethod == "PUT" }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **PATCH** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the PATCH method
 */
public func isMethodPATCH() -> HTTPStubsTestBlock {
  return { $0.httpMethod == "PATCH" }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **DELETE** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the DELETE method
 */
public func isMethodDELETE() -> HTTPStubsTestBlock {
  return { $0.httpMethod == "DELETE" }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **HEAD** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the HEAD method
 */
public func isMethodHEAD() -> HTTPStubsTestBlock {
    return { $0.httpMethod == "HEAD" }
}

/**
 * Matcher for testing an `NSURLRequest`'s **absolute url string**.
 *
* e.g. the absolute url string is `https://api.example.com/signin?user=foo&password=123#anchor` in `https://api.example.com/signin?user=foo&password=123#anchor`
 *
 * - Parameter url: The absolute url string to match
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            has the given absolute url
 */
public func isAbsoluteURLString(_ url: String) -> HTTPStubsTestBlock {
  return { req in req.url?.absoluteString == url }
}

/**
 * Matcher for testing an `NSURLRequest`'s **scheme**.
 *
 * e.g. the scheme part is `https` in `https://api.example.com/signin`
 *
 * - Parameter scheme: The scheme to match
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            has the given scheme
 */
public func isScheme(_ scheme: String) -> HTTPStubsTestBlock {
  precondition(!scheme.contains("://"), "The scheme part of an URL never contains '://'. Only use strings like 'https' for this value, and not things like 'https://'")
  precondition(!scheme.contains("/"), "The scheme part of an URL never contains any slash. Only use strings like 'https' for this value, and not things like 'https://api.example.com/'")
  return { req in req.url?.scheme == scheme }
}

/**
 * Matcher for testing an `NSURLRequest`'s **host**.
 *
 * e.g. the host part is `api.example.com` in `https://api.example.com/signin`.
 *
 * - Parameter host: The host to match (e.g. 'api.example.com')
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            has the given host
 */
public func isHost(_ host: String) -> HTTPStubsTestBlock {
  precondition(!host.contains("/"), "The host part of an URL never contains any slash. Only use strings like 'api.example.com' for this value, and not things like 'https://api.example.com/'")
  return { req in req.url?.host == host }
}

/**
 * Matcher for testing an `NSURLRequest`'s **path**.
 *
 * e.g. the path is `/signin` in `https://api.example.com/signin`.
 *
 * - Parameter path: The path to match
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            has exactly the given path
 *
 * - Note: URL paths are usually absolute and thus starts with a '/' (which you
 *         should include in the `path` parameter unless you're testing relative URLs)
 */
public func isPath(_ path: String) -> HTTPStubsTestBlock {
  return { req in req.url?.path == path }
}

private func getPath(_ req: URLRequest) -> String? {
  #if swift(>=3.0)
    return req.url?.path // In Swift 3, path is non-optional
  #else
    return req.url?.path
  #endif
}
/**
 * Matcher for testing the start of an `NSURLRequest`'s **path**.
 *
 * - Parameter path: The path to match
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request's
 *            path starts with the given string
 *
 * - Note: URL paths are usually absolute and thus starts with a '/' (which you
 *         should include in the `path` parameter unless you're testing relative URLs)
 */
public func pathStartsWith(_ path: String) -> HTTPStubsTestBlock {
  return { req in getPath(req)?.hasPrefix(path) ?? false }
}

/**
 * Matcher for testing the end of an `NSURLRequest`'s **path**.
 *
 * - Parameter path: The path to match
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request's
 *            path ends with the given string
 */
public func pathEndsWith(_ path: String) -> HTTPStubsTestBlock {
  return { req in getPath(req)?.hasSuffix(path) ?? false }
}

/**
 * Matcher for testing if the path of an `NSURLRequest` matches a RegEx.
 *
 * - Parameter regex: The Regular Expression we want the path to match
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request's
 *            path matches the given regular expression
 *
 * - Note: URL paths are usually absolute and thus starts with a '/'
 */
public func pathMatches(_ regex: NSRegularExpression) -> HTTPStubsTestBlock {
  return { req in
    guard let path = getPath(req) else { return false }
    let range = NSRange(location: 0, length: path.utf16.count)
    #if swift(>=3.0)
      return regex.firstMatch(in: path, options: [], range: range) != nil
    #else
      return regex.firstMatchInString(path, options: [], range: range) != nil
    #endif
  }
}

/**
 * Matcher for testing if the path of an `NSURLRequest` matches a RegEx.
 *
 * - Parameter regexString: The Regular Expression string we want the path to match
 * - Parameter options: The Regular Expression options to use.
 *                      Defaults to no option. Common option includes e.g. `.caseInsensitive`.
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request's
 *            path matches the given regular expression
 *
 * - Note: This is a convenience function building an NSRegularExpression
 *         and calling pathMatches(…) with it
 */
#if swift(>=3.0)
public func pathMatches(_ regexString: String, options: NSRegularExpression.Options = []) -> HTTPStubsTestBlock {
  guard let regex = try? NSRegularExpression(pattern: regexString, options: options) else {
    return { _ in false }
  }
  return pathMatches(regex)
}
#else
  public func pathMatches(_ regexString: String, options: NSRegularExpressionOptions = []) -> HTTPStubsTestBlock {
    guard let regex = try? NSRegularExpression(pattern: regexString, options: options) else {
      return { _ in false }
    }
    return pathMatches(regex)
  }
#endif

/**
 * Matcher for testing an `NSURLRequest`'s **path extension**.
 *
 * - Parameter ext: The file extension to match (without the dot)
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request path
 *            ends with the given extension
 */
public func isExtension(_ ext: String) -> HTTPStubsTestBlock {
  return { req in req.url?.pathExtension == ext }
}

/**
 * Matcher for testing an `NSURLRequest`'s **query parameters**.
 *
 * - Parameter params: The dictionary of query parameters to check the presence for
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds if the request contains
 *            the given query parameters with the given value.
 *
 * - Note: There is a difference between:
 *          (1) using `[q:""]`, which matches a query parameter "?q=" with an empty value, and
 *          (2) using `[q:nil]`, which matches a query parameter "?q" without a value at all
 */
@available(iOS 8.0, OSX 10.10, *)
public func containsQueryParams(_ params: [String:String?]) -> HTTPStubsTestBlock {
  return { req in
    if let url = req.url {
      let comps = NSURLComponents(url: url, resolvingAgainstBaseURL: true)
      if let queryItems = comps?.queryItems {
        for (k,v) in params {
          if queryItems.filter({ qi in qi.name == k && qi.value == v }).count == 0 { return false }
        }
        return true
      }
    }
    return false
  }
}

/**
 * Matcher testing that the `NSURLRequest` headers contain a specific key
 * - Parameter name: the name of the key to search for in the `NSURLRequest`'s **allHTTPHeaderFields** property
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s headers contain a value for the key name
 */
public func hasHeaderNamed(_ name: String) -> HTTPStubsTestBlock {
  return { (req: URLRequest) -> Bool in
    return req.value(forHTTPHeaderField: name) != nil
  }
}

/**
 * Matcher testing that the `NSURLRequest` headers contain a specific key and the key's value is equal to the parameter value
 * - Parameter name: the name of the key to search for in the `NSURLRequest`'s **allHTTPHeaderFields** property
 * - Parameter value: the value to compare against the header's value
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s headers contain a value for the key name and it's value
 *            is equal to the parameter value
 */
public func hasHeaderNamed(_ name: String, value: String) -> HTTPStubsTestBlock {
  return { (req: URLRequest) -> Bool in
    return req.value(forHTTPHeaderField: name) == value
  }
}

/**
 * Matcher testing that the `NSURLRequest` body contain exactly specific data bytes
 * - Parameter body: the Data bytes to expect
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s body is exactly the same as the parameter value
 */
#if swift(>=3.0)
  public func hasBody(_ body: Data) -> HTTPStubsTestBlock {
    return { req in (req as NSURLRequest).ohhttpStubs_HTTPBody() == body }
  }
#else
  public func hasBody(_ body: NSData) -> HTTPStubsTestBlock {
    return { req in req.OHOHHTTPStubs_HTTPBody() == body }
  }
#endif

/**
 * Matcher testing that the `NSURLRequest` body contains a JSON object with the same keys and values
 * - Parameter jsonObject: the JSON object to expect
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s body contains a JSON object with the same keys and values as the parameter value
 */
#if swift(>=3.0)
public func hasJsonBody(_ jsonObject: [AnyHashable : Any]) -> HTTPStubsTestBlock {
  return { req in
    guard
      let httpBody = req.ohhttpStubs_httpBody,
      let jsonBody = (try? JSONSerialization.jsonObject(with: httpBody, options: [])) as? [AnyHashable : Any]
    else {
      return false
    }
    return NSDictionary(dictionary: jsonBody).isEqual(to: jsonObject)
  }
}
#endif

#if swift(>=3.0)
/**
 * Matcher testing that the `NSURLRequest` content-type is `application/x-www-form-urlencoded` and body contains a query parameter
 *
 * - Parameter params: The dictionary of query parameters to check the presence for
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s body contains the same query items as the parameter value
 */
@available(iOS 8.0, OSX 10.10, *)
public func hasFormBody(_ params: [String: String?]) -> HTTPStubsTestBlock {
    return hasFormBody(params.map(URLQueryItem.init))
}

/**
 * Matcher testing that the `NSURLRequest` content-type is `application/x-www-form-urlencoded` and body contains a query parameter
 *
 * - Parameter queryItems: The array of query parameters to check the presence for
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s body contains the same query items as the parameter value
 */
@available(iOS 8.0, OSX 10.10, *)
public func hasFormBody(_ queryItems: [URLQueryItem]) -> HTTPStubsTestBlock {
    return { req in
        guard
            case "application/x-www-form-urlencoded"? = req.value(forHTTPHeaderField: "Content-Type"),
            let httpBody = req.ohhttpStubs_httpBody,
            let query = String(data: httpBody, encoding: .utf8)
            else { return false }
        let items: [URLQueryItem] = {
            var comps = URLComponents()
            comps.percentEncodedQuery = query
            return comps.queryItems ?? []
        }()
        return items.sorted(by: { $0.name < $1.name }) == queryItems.sorted(by: { $0.name < $1.name })
    }
}

/**
 * Matcher testing that the `NSURLRequest` content-type is `application/x-www-form-urlencoded` and body contains a query parameter
 *
 * - Parameter queryItems: The variables of query parameters to check the presence for
 *
 * - Returns: a matcher that returns true if the `NSURLRequest`'s body contains the same query items as the parameter value
 */
@available(iOS 8.0, OSX 10.10, *)
public func hasFormBody(_ queryItems: URLQueryItem...) -> HTTPStubsTestBlock {
    return hasFormBody(queryItems)
}
#endif

// MARK: Operators on HTTPStubsTestBlock

/**
 * Combine different `HTTPStubsTestBlock` matchers with an 'OR' operation.
 *
 * - Parameter lhs: the first matcher to test
 * - Parameter rhs: the second matcher to test
 *
 * - Returns: a matcher (`HTTPStubsTestBlock`) that succeeds if either of the given matchers succeeds
 */
#if swift(>=3.0)
  public func || (lhs: @escaping HTTPStubsTestBlock, rhs: @escaping HTTPStubsTestBlock) -> HTTPStubsTestBlock {
    return { req in lhs(req) || rhs(req) }
  }
#else
  public func || (lhs: HTTPStubsTestBlock, rhs: HTTPStubsTestBlock) -> HTTPStubsTestBlock {
    return { req in lhs(req) || rhs(req) }
  }
#endif

/**
 * Combine different `HTTPStubsTestBlock` matchers with an 'AND' operation.
 *
 * - Parameter lhs: the first matcher to test
 * - Parameter rhs: the second matcher to test
 *
 * - Returns: a matcher (`HTTPStubsTestBlock`) that only succeeds if both of the given matchers succeeds
 */
#if swift(>=3.0)
  public func && (lhs: @escaping HTTPStubsTestBlock, rhs: @escaping HTTPStubsTestBlock) -> HTTPStubsTestBlock {
    return { req in lhs(req) && rhs(req) }
  }
#else
  public func && (lhs: HTTPStubsTestBlock, rhs: HTTPStubsTestBlock) -> HTTPStubsTestBlock {
    return { req in lhs(req) && rhs(req) }
  }
#endif

/**
 * Create the opposite of a given `HTTPStubsTestBlock` matcher.
 *
 * - Parameter expr: the matcher to negate
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that only succeeds if the expr matcher fails
 */
#if swift(>=3.0)
  public prefix func ! (expr: @escaping HTTPStubsTestBlock) -> HTTPStubsTestBlock {
    return { req in !expr(req) }
  }
#else
  public prefix func ! (expr: HTTPStubsTestBlock) -> HTTPStubsTestBlock {
    return { req in !expr(req) }
  }
#endif
