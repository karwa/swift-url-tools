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
import WebURLTestSupport

extension Foundation.URL {

  var urlValues: URLValues {
    let url = self//.absoluteURL  // I think this is correct? How do I get the "most standard" URL string?
    return URLValues(
      href: url.absoluteString,
      origin: nil,
      protocol: url.scheme.map { $0 + ($0.isEmpty ? "" : ":") } ?? "",
      username: url.user ?? "",
      password: url.password ?? "",
      host: "<unsupported>",
      hostname: url.host ?? "",
      port: url.port.map { String($0) } ?? "",
      pathname: url.path,
      search: url.query.map { ($0.isEmpty ? "" : "?") + $0 } ?? "",
      hash: url.fragment.map { ($0.isEmpty ? "" : "#") + $0 } ?? ""
    )
  }

  var urlValuesViaComponents: URLValues {
    let components = URLComponents(url: self.absoluteURL.standardized, resolvingAgainstBaseURL: true)!
    return components.urlValues
  }
}

extension URLComponents {

  var urlValues: URLValues {
    return URLValues(
      href: string ?? "",
      origin: nil,
      protocol: scheme.map { $0 + ($0.isEmpty ? "" : ":") } ?? "",
      username: percentEncodedUser ?? "",
      password: percentEncodedPassword ?? "",
      host: "<unsupported>",
      hostname: percentEncodedHost ?? "",
      port: port.map { String($0) } ?? "",
      pathname: percentEncodedPath,
      search: percentEncodedQuery.map { ($0.isEmpty ? "" : "?") + $0 } ?? "",
      hash: percentEncodedFragment.map { ($0.isEmpty ? "" : "#") + $0 } ?? ""
    )
  }
}
