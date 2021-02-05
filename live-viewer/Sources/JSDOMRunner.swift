import Foundation

#if true // set to 'false' to try using JavascriptCore rather than WKWebView.

import WebKit

/// An object which calls the JSDOM reference URL implementation.
///
/// It uses an offscreen WKWebView, which isn't really ideal since it isn't available on Linux.
///
struct JSDOMRunner {
  private let webview = WKWebView(frame: .zero, configuration: .init())
  
  mutating func loadSiteIfNeeded() { 
    if webview.url == nil {
      webview.loadFileURL(
        Bundle.main.resourceURL!.appendingPathComponent("live-viewer", isDirectory: true).appendingPathComponent("index.html"),
        allowingReadAccessTo: Bundle.main.resourceURL!.appendingPathComponent("live-viewer", isDirectory: true)
      )
    }
  }
  
  func callAsFunction(input: String, base: String, completionHandler: @escaping (Result<(JSDataURLModel), Error>)->Void) {
    
    enum JSDomRunnerError: Error {
      case deserialisedToUnexpectedDataType
    }
    
    let js = #"""
    var url = new whatwgURL.URL(String.raw` \#(input) `, String.raw` \#(base) `);
    var entries = new Map();
    [ "href", "protocol", "username", "password", "hostname", "pathname", "search", "fragment" ].forEach(function(property){
      entries.set(property, url[property]);
    });
    JSON.stringify(Object.fromEntries(entries))
    """#
    webview.evaluateJavaScript(js) { maybeResult, maybeError in
      guard let resultString = maybeResult as? String else {
        completionHandler(.failure(maybeError!))
        return
      }
      do {
        guard let resultData = try JSONSerialization.jsonObject(with: resultString.data(using: .utf8)!, options: []) as? [String: String] else {
          completionHandler(.failure(JSDomRunnerError.deserialisedToUnexpectedDataType))
          return
        }
        completionHandler(.success(JSDataURLModel(data: resultData)))
      } catch {
        completionHandler(.failure(error))
      }
    }
  }
}

#else

import JavaScriptCore

/// An object which calls the JSDOM reference URL implementation.
///
/// It uses JavascriptCore directly rather than WKWebView.
///
struct JSDOMRunner {
  var context = JSContext()!
  var didLoad = false
  
  mutating func loadSiteIfNeeded() {
    if didLoad == false {
      let jsURL = Bundle.main.resourceURL!.appendingPathComponent("live-viewer", isDirectory: true).appendingPathComponent("whatwg-url.js")
      guard var jsContents = try? String(contentsOf: jsURL) else {
        print("Failed to read whatwg-url.js")
        return
      }
      // Taken from https://github.com/codesandbox/codesandbox-client/pull/4935/files
      // Seems to help? Maybe? 🤷‍♂️
      jsContents = jsContents.replacingOccurrences(of:
          #"Object.getOwnPropertyDescriptor(SharedArrayBuffer.prototype, "byteLength").get"#,
          with: #"false ? Object.getOwnPropertyDescriptor(SharedArrayBuffer.prototype, "byteLength").get : null;"#)
      
      let result = context.evaluateScript(jsContents)!
      if let exception = context.exception {
        print("context failed to load: \(exception)")
      }
      didLoad = true
    }
  }
  
  func callAsFunction(input: String, base: String, completionHandler: @escaping (Result<(JSDataURLModel), Error>)->Void) {
    
    enum JSDomRunnerError: Error {
      case contextException(JSValue)
      case deserialisedToUnexpectedDataType
    }
    
    // TODO: We need to escape quotes (at least) from input and base.
    let js = #"""
    var url = new whatwgURL.URL("\#(input)", "\#(base)");
    var entries = new Map();
    [ "href", "protocol", "username", "password", "hostname", "pathname", "search", "fragment" ].forEach(function(property){
      entries.set(property, url[property]);
    });
    JSON.stringify(Object.fromEntries(entries))
    """#
    if let result = context.evaluateScript(js), result.isString {
      print("JS result: \(result)")
      do {
        guard let resultData = try JSONSerialization.jsonObject(with: String(describing: result).data(using: .utf8)!, options: []) as? [String: String] else {
          completionHandler(.failure(JSDomRunnerError.deserialisedToUnexpectedDataType))
          return
        }
        completionHandler(.success(JSDataURLModel(data: resultData)))
      } catch {
        completionHandler(.failure(error))
      }
    } else if let exception = context.exception {
      print("JS exception: \(exception)")
      completionHandler(.failure(JSDomRunnerError.contextException(exception)))
    } else {
      assert(false, "JS didn't fail, also no exception?!")
    }
  }
}


#endif
