
/// A type which provides a compatible URL interface to the WHATWG spec's JS model.
///
protocol URLModel {
  var href: String { get }
  var scheme: String { get }
  var hostname: String { get }
  var port: String { get }
  var username: String { get }
  var password: String { get }
  var pathname: String { get }
  var search: String { get }
  var hash: String { get }
}

var allURLModelKeypaths: [KeyPath<URLModel, String>] {
  return [
    \.href, \.scheme, \.hostname, \.port, \.username, \.password, \.pathname, \.search, \.hash
  ]
}

extension URLModel {
  
  func unequalKeys<Other: URLModel>(comparedTo other: Other) -> [KeyPath<URLModel, String>] {
    var results = [KeyPath<URLModel, String>]()
    for modelKeypath in allURLModelKeypaths {
      if self[keyPath: modelKeypath] != other[keyPath: modelKeypath] {
        results.append(modelKeypath)
      }
    }
    return results
  }
}


// MARK: - Conformances.


// We've got lots of URL-looking types floating around here, so let's make sure we're clear what each of them are:
//
// - WebURL.JSModel: The thing we want to test. The JS-like interface to a WebURL.
// - URLValues:      From WebURLTestSupport. A complete spec of every testable URL value, usually read from a test file.
//
// - JSDataURLModel:     The data we got from the reference implementation via the JSDomRunner.
// - FoundationURLModel: A just-for-fun attempt at exposing a JS-like interface to Foundation's URL type.

import WebURL

extension WebURL.JSModel: URLModel {
  var hash: String {
    fragment
  }
}

import WebURLTestSupport

extension URLValues: URLModel {
  var scheme: String {
    self.protocol
  }
}

struct JSDataURLModel: URLModel {
  var data: [String: String]
  
  var href: String { data["href"] ?? "" }
  var scheme: String { data["protocol"] ?? "" }
  var hostname: String { data["hostname"] ?? "" }
  var port: String { data["port"] ?? "" }
  var username: String { data["username"] ?? "" }
  var password: String { data["password"] ?? "" }
  var pathname: String { data["pathname"] ?? "" }
  var search: String { data["search"] ?? "" }
  var hash: String { data["hash"] ?? "" }
}

// Note: Foundation doesn't match the WHATWG's Javascript model by any stretch.
//       It's only included for curiosity's sake.

import Foundation
struct FoundationURLModel: URLModel {
  private var url: URL
  
  init(url: URL) {
    self.url = url.standardized.absoluteURL
  }
  
  var href: String { url.absoluteString }
  var hostname: String { url.host ?? "" }
  var port: String { url.port.map { String($0) } ?? "" }
  var username: String { url.user ?? "" }
  var password: String { url.password ?? ""}
  var pathname: String { url.path }
  var scheme: String {
    // Add a trailing ":" because NSURL doesn't include it.
    url.scheme.map { $0 + ($0.isEmpty ? "" : ":") } ?? ""
  }
  var search: String {
    // Add a leading "?" because NSURL doesn't include it.
    url.query.map { ($0.isEmpty ? "" : "?") + $0 } ?? ""
  }
  var hash: String {
    // Add a leading "#" because NSURL doesn't include it.
    url.fragment.map { ($0.isEmpty ? "" : "#") + $0 } ?? ""
  }
}

