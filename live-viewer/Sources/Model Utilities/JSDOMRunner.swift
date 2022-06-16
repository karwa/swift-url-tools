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

import JavaScriptCore
import WebURLTestSupport

/// An actor providing serialized, async access to a JavaScript engine.
///
internal actor JavaScriptEngine {

  // A full JS interop design is out-of-scope for this project.
  //
  // JavaScriptCore is a bit of an odd API to bridge to Swift concurrency.
  // JSContext and JSValue are safe to use from any thread, but they will be internally
  // serialized and block other threads using the same underlying JSVirtualMachine:
  //
  // > The JavaScriptCore API is thread-safe—for example, you can create JSValue objects
  // > or evaluate scripts from any thread—however, all other threads attempting to use
  // > the same virtual machine must wait. To run JavaScript concurrently on multiple threads,
  // > use a separate JSVirtualMachine instance for each thread.
  //   https://developer.apple.com/documentation/javascriptcore/jsvirtualmachine
  //
  // In a complete design, we would probably want to wrap the JSValue and have it store a reference to this
  // actor, with all calls await-ing for a spot on the actor's executor so we serialize things in Swift-land
  // rather than internally within JavaScriptCore. Also, the JSValue API allows bridging native objects in to JS,
  // but I suspect that relies quite heavily on Obj-C and probably won't work for pure-Swift objects.
  //
  // For now, we serialize script execution via this actor, but we just sort of allow JSValues to escape
  // (again, they're thread-safe, although they may block this actor).
  // This actor is basically being used like a Dispatch serial queue.

  private let context = JSContext()!

  // --------------------------------------------
  // Initializers.
  // --------------------------------------------

  /// Initializes a new JavaScriptEngine.
  ///
  public init() {
    context.evaluateScript(
      #"""
      function __swift_classifyError(err) {
        if (err instanceof EvalError) {
          return \#(Exception.ErrorKind.evalError.rawValue)
        } else if (err instanceof RangeError) {
          return \#(Exception.ErrorKind.rangeError.rawValue)
        } else if (err instanceof ReferenceError) {
          return \#(Exception.ErrorKind.referenceError.rawValue)
        } else if (err instanceof SyntaxError) {
          return \#(Exception.ErrorKind.syntaxError.rawValue)
        } else if (err instanceof TypeError) {
          return \#(Exception.ErrorKind.typeError.rawValue)
        } else if (err instanceof URIError) {
          return \#(Exception.ErrorKind.URIError.rawValue)
        } else if (err instanceof AggregateError) {
          return \#(Exception.ErrorKind.aggregateError.rawValue)
        } else if (err instanceof InternalError) {
          return \#(Exception.ErrorKind.internalError.rawValue)
        } else {
          return \#(Exception.ErrorKind.unknownOrCustomError.rawValue)
        }
      }
      """#
    )
  }

  /// Initializes a new JavaScriptEngine, and prepares the environment by executing a collection of setup scripts.
  ///
  public convenience init(initialScripts: [String]) throws {
    self.init()
    for script in initialScripts {
      context.exception = nil
      context.evaluateScript(script)
      if let exception = context.exception { throw Exception(exception: exception, kind: .unknownOrCustomError) }
    }
  }

  // --------------------------------------------
  // Exceptions.
  // --------------------------------------------

  public struct Exception: Error, CustomStringConvertible {
    public var exception: JSValue
    public var kind: ErrorKind

    public enum ErrorKind: Int {
      case unknownOrCustomError
      case evalError
      case rangeError
      case referenceError
      case syntaxError
      case typeError
      case URIError
      case aggregateError
      case internalError
    }

    public var description: String {
      exception.toString()
    }
  }

  private func throwException(_ exception: JSValue) throws {
    guard
      let __errorKind = context.globalObject.invokeMethod("__swift_classifyError", withArguments: [exception]),
      let _errorKind = __errorKind.toNumber(),
      let errorKind = Exception.ErrorKind(rawValue: _errorKind.intValue)
    else {
      fatalError("Unable to classify JS Exception: \(exception.toString() ?? "<unprintable>")")
    }
    throw Exception(exception: exception, kind: errorKind)
  }

  // --------------------------------------------
  // Evaluating Scripts.
  // --------------------------------------------

  /// Evaluates the given script.
  ///
  /// If the script throws an unhandled JavaScript exception, this function throws a `JavaScriptEngine.Exception`.
  ///
  public func evaluate(_ script: String) throws -> JSValue? {
    context.exception = nil
    guard let result = context.evaluateScript(script) else {
      return nil
    }
    if let exception = context.exception {
      try throwException(exception)
    }
    guard !result.isUndefined else {
      return nil  // Can we do anything better here? undefined is not the same as null.
    }
    guard !result.isNull else {
      return nil
    }
    return result
  }
}

// --------------------------------------------
// MARK: - JSDOM Runner.
// --------------------------------------------

/// An object which parses URLs using the JSDOM reference implementation in a JavaScriptCore context.
///
internal struct JSDOMRunner {
  private let engine: JavaScriptEngine

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

    self.engine = try! JavaScriptEngine(initialScripts: [
      try! JSDOMRunner.getPolyfillScript(name: "base64"),
      try! JSDOMRunner.getPolyfillScript(name: "encoding-indexes"),
      try! JSDOMRunner.getPolyfillScript(name: "encoding"),
      try! String(contentsOf: liveViewerLocation),
    ])
  }

  // --------------------------------------------
  // URL Parsing.
  // --------------------------------------------

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
    } catch let err as JavaScriptEngine.Exception where err.kind == .typeError {
      return nil
    } catch {
      fatalError("Unknown JS exception: \(error)")
    }
  }

  // --------------------------------------------
  // Batch Processing.
  // --------------------------------------------

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

    let runner = JSDOMRunner()
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

extension JSContext: @unchecked Sendable {}
extension JSValue: @unchecked Sendable {}

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
