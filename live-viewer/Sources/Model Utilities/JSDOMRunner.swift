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

import WebURLTestSupport

#if false  // 'true' = use offscreen WKWebView, 'false' = use JavaScriptCore

  import WebKit

  /// An object which parses URLs using the JSDOM reference implementation in an offscreen WKWebView.
  ///
  internal struct JSDOMRunner {
    private let webview: WKWebView

    private enum Error: Swift.Error {
      case deserialisedToUnexpectedDataType
    }

    /// Creates a JSDOM runner. Call this if you are not in a @MainActor-isolated context.
    ///
    public static func createFromNonMainActor() async -> JSDOMRunner {
      await MainActor.run { JSDOMRunner() }
    }

    // FIXME: This should be @MainActor, but we can't do that because it would prevent its use in view-model structs.
    //        SwiftUI 2.0 doesn't support view-model structs being declared @MainActor.
    //
    //        Instead, we trust SwiftUI to create these things on the Main actor anyway,
    //        and use 'createFromNonMainActor' from non-@MainActor-isolated functions.
    public init() {
      webview = WKWebView(frame: .zero, configuration: .init())

      let liveViewerData = Bundle.main.resourceURL!.appendingPathComponent("live-viewer", isDirectory: true)
      webview.loadFileURL(
        liveViewerData.appendingPathComponent("index.html"),
        allowingReadAccessTo: liveViewerData
      )
    }

    /// Parses the given input string against the given base URL string.
    /// If parsing fails, this function returns `nil`.
    ///
    /// Any internal errors encountered while evaluating the JavaScript are considered
    /// non-recoverable and will result in a `fatalError`.
    ///
    public func parse(input: String, base: String?) async -> URLValues? {

      // Hack: we need to make sure the webview has loaded before we proceed.
      while await webview.isLoading {
        try? await Task.sleep(nanoseconds: UInt64(0.3 * 1E9) /* 300ms */)
      }

      // To escape the strings, first percent-encode to make everything ASCII and then base64-encode
      // to reduce the character set. Javascript's 'atob' will restore the percent-encoded version,
      // which decodeURIComponent will use to restore the original content.
      let escapedInput = Data(input.percentEncoded(using: .urlComponentSet).utf8).base64EncodedString()
      var js = #"var url = new whatwgURL.URL(decodeURIComponent(window.atob('\#(escapedInput)'))"#
      if let base = base {
        let escapedBase = Data(base.percentEncoded(using: .urlComponentSet).utf8).base64EncodedString()
        js += #", decodeURIComponent(window.atob('\#(escapedBase)')));"#
      } else {
        js += #");"#
      }
      js += #"""
        var entries = new Map();
        [ "href", "protocol", "username", "password", "host", "hostname", "origin", "port", "pathname", "search", "hash" ].forEach(function(property){
          entries.set(property, url[property]);
        });
        JSON.stringify(Object.fromEntries(entries))
        """#

      // Since this is being invoked on a WKWebView, we need to call evaluteJavaScript from the Main actor.
      // However, that function is itself async and runs on some background thread.
      return try! await Task { @MainActor [js] in
        guard let result = try? await webview.evaluateJavaScript(js) as? String else {
          return nil
        }
        let resultData = result.data(using: .utf8)!
        guard let resultDict = try? JSONSerialization.jsonObject(with: resultData) as? [String: String] else {
          fatalError("Failed to parse JSON response")
        }
        return URLValues(resultDict)
      }.result.get()
    }
  }

#else

  import JavaScriptCore

  internal actor JavaScriptEngine {

    // The JavaScriptCore API is thread-safe—for example, you can create JSValue objects
    // or evaluate scripts from any thread—however, all other threads attempting to use
    // the same virtual machine must wait. To run JavaScript concurrently on multiple threads,
    // use a separate JSVirtualMachine instance for each thread.
    // https://developer.apple.com/documentation/javascriptcore/jsvirtualmachine

    private let context = JSContext()!
    private let typeErrorClass: JSValue

    public struct TypeError: Error {
      var exception: JSValue
    }
    public struct Exception: Error {
      var exception: JSValue
    }

    private static func loadScript(script: String, context: JSContext) throws {
      let _ = context.evaluateScript(script)
      if let exception = context.exception { throw Exception(exception: exception) }
    }

    // Init.

    public init() {
      typeErrorClass = context.evaluateScript("TypeError")
    }

    public convenience init(initialScripts: [String]) throws {
      self.init()
      for script in initialScripts {
        try JavaScriptEngine.loadScript(script: script, context: context)
      }
    }

    // Raw context access.

    public func withJSContext<T>(_ body: (JSContext) throws -> T) rethrows -> T {
      try body(context)
    }

    // Evaluating scripts.

    // JSValue is a bit of an odd fit because it allows calling functions and such;
    // thankfully, that is thread-safe, although those functions may change global state and interfere
    // with the result of scripts that execute via the actor.
    // A full JS interop design is out-of-scope for this project, however.

    public func evaluate(_ script: String) throws -> JSValue? {
      let result = context.evaluateScript(script)
      if result?.isUndefined == true, let exception = context.exception {
        if exception.isInstance(of: typeErrorClass) {
          throw TypeError(exception: exception)
        }
        throw Exception(exception: exception)
      }
      return result
    }
  }

  /// An object which parses URLs using the JSDOM reference implementation in a JavaScriptCore context.
  ///
  internal struct JSDOMRunner {
    private let engine: JavaScriptEngine

    // Note: createFromNonMainActor() is only necessary for WKWebView. Implemented here so they have the same API.

    /// Creates a JSDOM runner. Call this if you are not in a @MainActor-isolated context.
    ///
    public static func createFromNonMainActor() async -> JSDOMRunner {
      JSDOMRunner()
    }

    private static func getPolyfillScript(name: String) throws -> String {
      return try String(
        contentsOf: Bundle.main.resourceURL!
          .appendingPathComponent("polyfills", isDirectory: true)
          .appendingPathComponent("\(name).js")
      )
    }

    public init() {

      let liveViewerLocation = Bundle.main.resourceURL!
        .appendingPathComponent("live-viewer", isDirectory: true)
        .appendingPathComponent("whatwg-url.js")
      var liveViewerScript = try! String(contentsOf: liveViewerLocation)
      // Hack from https://github.com/codesandbox/codesandbox-client/pull/4935/files
      liveViewerScript = liveViewerScript.replacingOccurrences(
        of: #"Object.getOwnPropertyDescriptor(SharedArrayBuffer.prototype, "byteLength").get"#,
        with: #"false ? Object.getOwnPropertyDescriptor(SharedArrayBuffer.prototype, "byteLength").get : null;"#
      )

      self.engine = try! JavaScriptEngine(initialScripts: [
        try! JSDOMRunner.getPolyfillScript(name: "base64"),
        try! JSDOMRunner.getPolyfillScript(name: "TextEncoderDecoder"),
        liveViewerScript
      ])
    }

    /// Parses the given input string against the given base URL string.
    /// If parsing fails, this function returns `nil`.
    ///
    /// Any internal errors encountered while evaluating the JavaScript are considered
    /// non-recoverable and will result in a `fatalError`.
    ///
    public func parse(input: String, base: String?) async -> URLValues? {

      // To escape the strings, first percent-encode to make everything ASCII and then base64-encode
      // to reduce the character set. Javascript's 'atob' will restore the percent-encoded version,
      // which decodeURIComponent will use to restore the original content.
      let escapedInput = Data(input.percentEncoded(using: .urlComponentSet).utf8).base64EncodedString()
      var js = #"new whatwgURL.URL(decodeURIComponent(Base64.atob('\#(escapedInput)'))"#
      if let base = base {
        let escapedBase = Data(base.percentEncoded(using: .urlComponentSet).utf8).base64EncodedString()
        js += #", decodeURIComponent(Base64.atob('\#(escapedBase)'))"#
      }
      js += #");"#

      do {
        return try await engine.evaluate(js).map { URLValues($0) }
      } catch _ as JavaScriptEngine.TypeError {
        return nil
      } catch {
        fatalError("Unknown JS exception: \(error)")
      }
    }
  }

#endif


// --------------------------------------------
// MARK: - Batch Processing.
// --------------------------------------------


extension JSDOMRunner {

  /// Executes a series of tests on the JSDOM URL reference implementation.
  ///
  /// - parameters:
  ///   - tests:          A series of inputs in a type of your choosing.
  ///   - extractValues:  Extract an input URL string and base URL string from each value in `tests`.
  ///                     If the input does not contain a test-case, return `nil`.
  ///   - generateResult: Maps a test number, input, and set of parsed URL values to a result type of your choosing.
  ///                     If the result should be ignored, return `nil`.
  ///
  static func runAll<TestInput, TestResult>(
    tests testInputs: [TestInput],
    extractValues: (TestInput) -> (input: String, base: String?)?,
    generateResult: (Int, TestInput, URLValues?) -> TestResult?
  ) async -> [TestResult] {

    let runner = await JSDOMRunner.createFromNonMainActor()
    var results = [TestResult]()
    var number = 0
    for testInput in testInputs {
      guard let testcase = extractValues(testInput) else { continue }
      let referenceResult = await runner.parse(input: testcase.input, base: testcase.base)
      if let result = generateResult(number, testInput, referenceResult) {
        results.append(result)
      }
      number += 1
    }
    return results
  }
}


// --------------------------------------------
// MARK: - Utilities.
// --------------------------------------------


extension JSValue {

  fileprivate func getString(_ name: String) -> String? {
    guard let propertyValue = objectForKeyedSubscript(name) else {
      return nil
    }
    return propertyValue.isString ? propertyValue.toString() : nil
  }
}

extension URLValues {

  fileprivate init(_ jsValue: JSValue) {
    self.init(
      href: jsValue.getString("href") ?? "",
      origin: jsValue.getString("origin") ?? "",
      protocol: jsValue.getString("protocol") ?? "",
      username: jsValue.getString("username") ?? "",
      password: jsValue.getString("password") ?? "",
      host: jsValue.getString("host") ?? "",
      hostname: jsValue.getString("hostname") ?? "",
      port: jsValue.getString("port") ?? "",
      pathname: jsValue.getString("pathname") ?? "",
      search: jsValue.getString("search") ?? "",
      hash: jsValue.getString("hash") ?? ""
    )
  }
}

extension URLValues {

  fileprivate init(_ dict: [String: String]) {
    self.init(
      href: dict["href", default: ""], origin: dict["origin"],
      protocol: dict["protocol", default: ""],
      username: dict["username", default: ""], password: dict["password", default: ""],
      host: dict["host", default: ""], hostname: dict["hostname", default: ""],
      port: dict["port", default: ""],
      pathname: dict["pathname", default: ""],
      search: dict["search", default: ""], hash: dict["hash", default: ""]
    )
  }
}
