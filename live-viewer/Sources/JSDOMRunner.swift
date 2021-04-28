import Foundation

import WebURLTestSupport

extension URLValues {
  
  fileprivate init(_ dict: [String: String]) {
    self.init(
      href: dict["href", default: ""], origin: dict["origin"], protocol: dict["protocol", default: ""],
      username: dict["username", default: ""], password: dict["password", default: ""],
      host: dict["host", default: ""], hostname: dict["hostname", default: ""], port: dict["port", default: ""],
      pathname: dict["pathname", default: ""], search: dict["search", default: ""], hash: dict["hash", default: ""]
    )
  }
}

#if true // set to 'false' to try using JavascriptCore rather than WKWebView.

import WebKit

/// An object which calls the JSDOM reference URL implementation.
///
/// It uses an offscreen WKWebView, which isn't really ideal since it isn't available on Linux.
/// Must only be called on the main queue.
///
struct JSDOMRunner {
  private let webview = WKWebView(frame: .zero, configuration: .init())
  
  init() {
    webview.loadFileURL(
      Bundle.main.resourceURL!.appendingPathComponent("live-viewer", isDirectory: true).appendingPathComponent("index.html"),
      allowingReadAccessTo: Bundle.main.resourceURL!.appendingPathComponent("live-viewer", isDirectory: true)
    )
  }

  /// Must only be called on the main queue. The given completion handler is also invoked on the main queue.
  ///
  func callAsFunction(input: String, base: String, completionHandler: @escaping (Result<(URLValues), Error>)->Void) {
    
    enum JSDomRunnerError: Error {
      case deserialisedToUnexpectedDataType
    }
    
    // Bit of a cheap hack: we need to make sure the webview had loaded before we proceed.
    if webview.isLoading {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
        self(input: input, base: base, completionHandler: completionHandler)
      }
      return
    }
    
    // To escape the strings, first percent-encode to make everything ASCII and then base64-encode
    // to reduce the character set. Javascript's 'atob' will restore the percent-encoded version,
    // which decodeURIComponent will use to restore the original content.
    let escapedInput = Data(input.urlComponentEncoded.utf8).base64EncodedString()
    let escapedBase = Data(base.urlComponentEncoded.utf8).base64EncodedString()
    
    let js = #"""
    var url = new whatwgURL.URL(decodeURIComponent(window.atob('\#(escapedInput)')), decodeURIComponent(window.atob('\#(escapedBase)')));
    var entries = new Map();
    [ "href", "protocol", "username", "password", "host", "hostname", "origin", "port", "pathname", "search", "hash" ].forEach(function(property){
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
        guard let resultData = try JSONSerialization.jsonObject(
                with: resultString.data(using: .utf8)!, options: []
        ) as? [String: String] else {
          completionHandler(.failure(JSDomRunnerError.deserialisedToUnexpectedDataType))
          return
        }
        
        completionHandler(.success(URLValues(resultData)))
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
  
  init() {
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
  }
  
  func callAsFunction(input: String, base: String, completionHandler: @escaping (Result<(URLValues), Error>)->Void) {
    
    enum JSDomRunnerError: Error {
      case contextException(JSValue)
      case deserialisedToUnexpectedDataType
    }
    
    // To escape the strings, first percent-encode to make everything ASCII and then base64-encode
    // to reduce the character set. Javascript's 'atob' will restore the percent-encoded version,
    // which decodeURIComponent will use to restore the original content.
    let escapedInput = Data(input.urlEncoded.utf8).base64EncodedString()
    let escapedBase = Data(base.urlEncoded.utf8).base64EncodedString()
    
    let js = #"""
    var url = new whatwgURL.URL(decodeURIComponent(window.atob('\#(escapedInput)')), decodeURIComponent(window.atob('\#(escapedBase)')));
    var entries = new Map();
    [ "href", "protocol", "username", "password", "host", "hostname", "origin", "port", "pathname", "search", "hash" ].forEach(function(property){
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
        completionHandler(.success(URLValues(resultData)))
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


// MARK: - Batch Processing.


extension JSDOMRunner {
  
  /// Executes a series of tests on the JSDOM URL reference implementation, one at a time, generating a result from each, and delivers the
  /// collected results asynchronously as an Array.
  ///
  final class BatchRunner<TestInput, TestResult> {

    static func run(
      each testInputs: [TestInput],
      extractValues: @escaping (TestInput) -> (input: String, base: String)?,
      generateResult: @escaping (Int, TestInput, URLValues?)->TestResult?,
      completion: @escaping ([TestResult])->Void
    ) -> AnyObject {
      let gen = BatchRunner(extractValues: extractValues, generateResult: generateResult, completion: completion)
      gen.runNextTest(number: 0, testInputs[...])
      return gen
    }
    
    var results: [TestResult]
    var jsRunner: JSDOMRunner

    let extractValues: (TestInput) -> (input: String, base: String)?
    let generateResult: (Int, TestInput, URLValues?) -> TestResult?
    let completion: ([TestResult]) -> Void

    private init(
      extractValues: @escaping (TestInput) -> (input: String, base: String)?,
      generateResult: @escaping (Int, TestInput, URLValues?) -> TestResult?,
      completion: @escaping ([TestResult]) -> Void
    ) {
      self.results = []
      self.jsRunner = JSDOMRunner()
      self.extractValues = extractValues
      self.generateResult = generateResult
      self.completion = completion
    }
    
    private func runNextTest(number: Int, _ remaining: ArraySlice<TestInput>) {
      var remaining = remaining
      guard let testcase = remaining.popFirst() else {
        completion(results) // Finished.
        return
      }
      guard let inputValues = extractValues(testcase) else {
        return self.runNextTest(number: number, remaining)
      }
      jsRunner(input: inputValues.input, base: inputValues.base) { [weak self] referenceResult in
        guard let self = self else { return }
        if let unexpectedResult = self.generateResult(number, testcase, try? referenceResult.get()) {
          self.results.append(unexpectedResult)
        }
        return self.runNextTest(number: number + 1, remaining)
      }
    }
  }
}
