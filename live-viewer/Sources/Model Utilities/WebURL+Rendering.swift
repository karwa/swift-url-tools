// Copyright The swift-url Contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import WebURL

// --------------------------------------------
// MARK: - WebURL.NSAttributedStringStyle protocol
// --------------------------------------------

extension WebURL {
  public typealias NSAttributedStringStyle = _WebURL_NSAttributedStringStyle
}

public protocol _WebURL_NSAttributedStringStyle {

  /// Attributes to apply to the URL's entire serialization.
  ///
  /// - parameters:
  ///   - url: The URL whose serialization is being styled.
  ///
  func baseAttributes(_ url: WebURL) -> [NSAttributedString.Key: Any]?

  /// A callback which is invoked after the URL has been entirely styled.
  ///
  /// - parameters:
  ///   - result:  The styled attributed string.
  ///   - url:     The URL whose serialization was styled.
  ///
  func prepareFinalResult(_ result: NSMutableAttributedString, url: WebURL)

  // Components:

  /// Attributes to apply to the URL's scheme.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func schemeAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the URL's username.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func usernameAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the URL's password.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func passwordAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the URL's hostname.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func hostnameAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the URL's port.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func portAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the URL's path.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func pathAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the given path componnt.
  ///
  /// - parameters:
  ///   - i:      The number of the path component, starting at 0.
  ///   - total:  The total number of path components (equal to `url.pathComponents.count`).
  ///   - index:  The index of the path component being styled.
  ///   - url:    The URL whose serialization is being styled.
  ///
  func pathComponentAttributes(
    number i: Int, of total: Int, index: WebURL.PathComponents.Index, url: WebURL
  ) -> [NSAttributedString.Key: Any]?

  /// Attributes to apply to the URL's query.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func queryAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?

  //  /// Attributes to apply to the given query parameter.
  //  ///
  //  /// - parameters:
  //  ///   - i:      The number of the query parameter, starting at 0.
  //  ///   - total:  The total number of query parameter (equal to `queryParams.count`).
  //  ///   - index:  The index of the query parameter being styled.
  //  ///   - url:    The URL whose serialization is being styled.
  //  ///
  //  func queryParamsAttributes(
  //    number i: Int, of total: Int, index: LazilySplitQueryParameters<WebURL.UTF8View.SubSequence>.Index, url: WebURL
  //  ) -> (key: [NSAttributedString.Key: Any]?, value: [NSAttributedString.Key: Any]?)

  /// Attributes to apply to the URL's fragment.
  ///
  /// - parameters:
  ///   - url:  The URL whose serialization is being styled.
  ///
  func fragmentAttributes(url: WebURL) -> [NSAttributedString.Key: Any]?
}

// Default implementations.

extension WebURL.NSAttributedStringStyle {

  public func baseAttributes(_ url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func prepareFinalResult(_ result: NSMutableAttributedString, url: WebURL) {
  }
  public func schemeAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func usernameAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func passwordAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func hostnameAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func portAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func pathAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func pathComponentAttributes(
    number i: Int, of total: Int, index: WebURL.PathComponents.Index, url: WebURL
  ) -> [NSAttributedString.Key: Any]? {
    nil
  }
  public func queryAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
  //  func queryParamsAttributes(
  //    number i: Int, of total: Int, index: LazilySplitQueryParameters<WebURL.UTF8View.SubSequence>.Index, url: WebURL
  //  ) -> (key: [NSAttributedString.Key: Any]?, value: [NSAttributedString.Key: Any]?) {
  //    (nil, nil)
  //  }
  public func fragmentAttributes(url: WebURL) -> [NSAttributedString.Key: Any]? {
    nil
  }
}

// --------------------------------------------
// MARK: - Rendering to a NSAttributedString
// --------------------------------------------

extension WebURL.UTF8View.SubSequence {

  fileprivate func sameSlice(in string: String) -> Substring {
    let start = string.utf8.index(string.startIndex, offsetBy: self.startIndex)
    let end = string.utf8.index(start, offsetBy: self.count)
    return string[start..<end]  //NSRange(start..<end, in: string)
  }
}

extension Substring {

  fileprivate func nsRangeInBase() -> NSRange {
    NSRange(startIndex..<endIndex, in: base)
  }
}

extension WebURL.NSAttributedStringStyle {

  public func render(_ url: WebURL) -> NSAttributedString {

    let urlString = url.serialized()
    let result = NSMutableAttributedString(string: urlString)

    // Base attributes for the entire string.
    if let base = baseAttributes(url) {
      result.addAttributes(base, range: NSRange(location: 0, length: result.length))
    }

    // Add styles for the various components.
    scheme: do {
      let slice = url.utf8.scheme
      guard let attributes = schemeAttributes(url: url) else { break scheme }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    username: do {
      guard
        let attributes = usernameAttributes(url: url),
        let slice = url.utf8.username
      else { break username }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    password: do {
      guard
        let attributes = passwordAttributes(url: url),
        let slice = url.utf8.password
      else { break password }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    hostname: do {
      guard
        let attributes = hostnameAttributes(url: url),
        let slice = url.utf8.hostname
      else { break hostname }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    port: do {
      guard
        let attributes = portAttributes(url: url),
        let slice = url.utf8.port
      else { break port }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    path: do {
      guard let attributes = pathAttributes(url: url) else { break path }
      let slice = url.utf8.path
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    pathComponents: do {
      guard !url.hasOpaquePath else { break pathComponents }
      let numberOfComponents = url.pathComponents.count
      var i = 0
      for index in url.pathComponents.indices {
        assert(numberOfComponents > 0)
        if let attributes = pathComponentAttributes(
          number: i, of: numberOfComponents, index: index, url: url)
        {
          let slice = url.utf8.pathComponent(index)
          result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
        }
        i += 1
      }
    }
    query: do {
      guard
        let attributes = queryAttributes(url: url),
        let slice = url.utf8.query
      else { break query }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }
    //    queryParams: do {
    //      guard url.utf8.query != nil else { break queryParams }
    //      let numberOfComponents = url.utf8.queryParams.count
    //      var i = 0
    //      for index in url.utf8.queryParams.indices {
    //        assert(numberOfComponents > 0)
    //        let attributes = queryParamsAttributes(number: i, of: numberOfComponents, index: index, url: url)
    //        if let keyAttributes = attributes.key {
    //          result.addAttributes(keyAttributes, range: url.utf8.queryParams[index].key.sameSlice(in: urlString).nsRangeInBase())
    //        }
    //        if let valueAttributes = attributes.value {
    //          result.addAttributes(valueAttributes, range: url.utf8.queryParams[index].value.sameSlice(in: urlString).nsRangeInBase())
    //        }
    //        i += 1
    //      }
    //    }
    fragment: do {
      guard
        let attributes = fragmentAttributes(url: url),
        let slice = url.utf8.fragment
      else { break fragment }
      result.addAttributes(attributes, range: slice.sameSlice(in: urlString).nsRangeInBase())
    }

    // Final callback.
    prepareFinalResult(result, url: url)
    return result
  }
}
