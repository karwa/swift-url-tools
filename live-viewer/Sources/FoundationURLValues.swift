import Foundation
import WebURLTestSupport

extension Foundation.URL {
  
  var urlValues: URLValues {
    let url = self.standardized.absoluteURL // I think this is correct? How do I get the "most standard" URL string?
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
}
