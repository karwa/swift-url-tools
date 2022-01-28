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

import SwiftUI
import WebURL
import WebURLTestSupport

struct BatchRunner: View {
  @Binding var modelData: ModelData
  @State var isImportingFile = false

  struct ModelData {
    private static let kBatch_LastFile = "batch_lastfile"

    /// The file containing the batch data to process.
    ///
    var sourceFile: URL? = .none {
      didSet { UserDefaults.standard.set(try? sourceFile?.bookmarkData(), forKey: Self.kBatch_LastFile) }
    }

    /// The state of the batch processing operation.
    ///
    var resultsState: ResultsState? = .none {
      didSet { selectedItem = nil }
    }

    /// The currently-selected constructor test result.
    ///
    var selectedItem: WPTConstructorTest.Result? = .none

    /// A queue to run WebURL tests on.
    ///
    let webURLRunnerQueue = DispatchQueue(label: "WebURL batch testing")

    enum ResultsState {
      case parseError(Error)
      case running
      case finished([WPTConstructorTest.Result])

      var isRunning: Bool {
        if case .running = self {
          return true
        }
        return false
      }
    }

    init() {
      if let bookmarkData = UserDefaults.standard.data(forKey: Self.kBatch_LastFile) {
        var isStale = false
        let resolvedURL = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
        if isStale {
          UserDefaults.standard.set(try? resolvedURL?.bookmarkData(), forKey: Self.kBatch_LastFile)
        }
        self.sourceFile = resolvedURL
      }
    }
  }
}


// --------------------------------------------
// MARK: - View Body
// --------------------------------------------


extension BatchRunner {

  var body: some View {
    VStack {
      filePickerAndActions
      Divider()
      resultsProgress
    }
  }

  private var filePickerAndActions: some View {
    VStack(spacing: 8) {
      GroupBox(label: Text("Batch Test File")) {
        HStack {
          Spacer()
          Text(modelData.sourceFile?.path ?? "No file selected")
            .lineLimit(2)
          Button("Choose...") { isImportingFile = true }
          Spacer()
        }
        .padding(.all, 8)
        .fileImporter(
          isPresented: $isImportingFile,
          allowedContentTypes: [.json],
          onCompletion: { result in
            guard let selectedFile = try? result.get() else {
              return
            }
            modelData.sourceFile = selectedFile
          }
        )
      }
      HStack {
        Spacer()
        Button("Test with WebURL") { runTestsWithWebURL() }
        Button("Verify with JSDOM") { Task { await runVerifyWithJSDOM() } }
      }.disabled(modelData.sourceFile == nil || modelData.resultsState?.isRunning == true)
      Spacer()
      VStack(alignment: .leading) {
        HStack(alignment: .top) {
          Text("-")
          Text("'Test with WebURL' runs a full WPT URL constructor test.")
        }
        HStack(alignment: .top) {
          Text("-")
          Text("'Verify with JSDOM' parses the input and base strings and checks the property values. " +
               "It is not a full constructor test.")
        }
      }.foregroundColor(.secondary)
    }
    #if !os(macOS)
      .navigationBarTitleDisplayMode(.large)
      .navigationTitle("Batch Mode")
    #endif
  }

  @ViewBuilder
  private var resultsProgress: some View {
    switch modelData.resultsState {
    case .none:
      Text("No results to display")
        .padding(.top, 10)
        .foregroundColor(.secondary)
    case .parseError(let error):
      Text("🔥 Failed to parse:\n \(error.localizedDescription)")
        .padding(.top, 10)
        .foregroundColor(.red)
    case .running:
      Text("Running...")
        .padding(.top, 10)
        .foregroundColor(.secondary)
    case .finished(let mismatches):
      if mismatches.isEmpty {
        Text("✅ No mismatches found")
          .bold()
          .padding(.top, 10)
          .foregroundColor(.green)
      } else {
        resultsList(mismatches: mismatches)
      }
    }
  }

  #if os(macOS)
    private func resultsList(mismatches: [WPTConstructorTest.Result]) -> some View {
      // On macOS, we don't have a global NavigationView (because SwiftUI just crashes, see 'App.swift'),
      // and a local NavigationView is horribly broken in all sorts of interesting ways.
      // Instead, use a HStack for a SplitView-esque presentation.
      HStack(alignment: .top, spacing: 12) {
        VStack {
          Text("\(mismatches.count) mismatches 😭")
            .foregroundColor(.red)
            .font(.title)
            .fontWeight(.bold)
          // For some reason, this breaks if id == \.testNumber. Works on iOS 🤷‍♂️.
          List(mismatches, id: \.self, selection: $modelData.selectedItem) { resultRow($0, chevron: false) }
        }
        .frame(width: 200, height: 500)  // FIXME: Yuck. Would love to make just make each column equal-height.
        if let selectedResult = modelData.selectedItem {
          MismatchInspector(testResult: .constant(selectedResult))
        }
      }
    }
  #else
    private func resultsList(mismatches: [WPTConstructorTest.Result]) -> some View {
      // On non-macOS platforms, we have a global NavigationView, so use a NavigationLink to show the details view.
      // We don't want a ScrollView-in-a-ScrollView, so use a LazyVStack rather than a List.
      // This means we don't have selection or keyboard navigation. C'est la vie.
      VStack {
        Text("\(mismatches.count) mismatches 😭")
          .foregroundColor(.red)
          .font(.title)
          .fontWeight(.bold)
        GroupBox {
          LazyVStack {
            ForEach(mismatches, id: \.testNumber) { entry in
              NavigationLink(
                destination: { ScrollView { MismatchInspector(testResult: .constant(entry)) } },
                label: { resultRow(entry, chevron: true) }
              )
              if entry.testNumber != mismatches.last?.testNumber {
                Divider()
              }
            }
          }
        }
      }
    }
  #endif

  private func resultRow(_ testResult: WPTConstructorTest.Result, chevron: Bool) -> some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading) {
        Text("\(testResult.testcase.input)")
          .lineLimit(1)
          .foregroundColor(.primary)
        Text("\(testResult.testcase.base ?? "")")
          .lineLimit(1)
          .foregroundColor(.secondary)
      }
      Spacer()
      Divider()
      Badge(String(testResult.testNumber)).badgeColor(.yellow).badgeTextColor(.black)
      if chevron {
        Image(systemName: "chevron.forward")
          .foregroundColor(.primary)
      }
    }
  }
}


// --------------------------------------------
// MARK: - Event Handlers.
// --------------------------------------------


extension BatchRunner {

  private func parseSourceFileOrSetError() -> [WPTConstructorTest.FileEntry]? {
    guard let selectedFileURL = modelData.sourceFile else {
      modelData.resultsState = nil
      return nil
    }
    do {
      return try JSONDecoder().decode([WPTConstructorTest.FileEntry].self, from: try Data(contentsOf: selectedFileURL))
    } catch {
      modelData.resultsState = .parseError(error)
      return nil
    }
  }

  @MainActor
  fileprivate func runVerifyWithJSDOM() async {
    guard let fileContents = parseSourceFileOrSetError() else { return }
    modelData.resultsState = .running

    let mismatches = await JSDOMRunner.runAll(
      tests: fileContents,
      extractValues: {
        // Extract (input, base) pair from FileEntry.
        (entry: WPTConstructorTest.FileEntry) -> (String, String?)? in

        if case .testcase(let test) = entry {
          return (test.input, test.base)
        }
        return nil
      },
      generateResult: {
        // Check to see if the result is a mismatch.
        // This doesn't perform the entire range of checks that a full WPTConstructorTest does.
        (testNumber, testcase, actual) -> WPTConstructorTest.Result? in

        guard case .testcase(let testcase) = testcase else {
          preconditionFailure("Should only see test cases here")
        }
        guard let referenceResult = actual else {
          guard testcase.failure else {
            return WPTConstructorTest.Result(
              testNumber: testNumber, testcase: testcase,
              propertyValues: nil, failures: .unexpectedFailureToParse
            )
          }
          // Success. Correct failure to parse.
          return nil
        }
        guard let expectedResult = testcase.expectedValues else {
          return WPTConstructorTest.Result(
            testNumber: testNumber, testcase: testcase,
            propertyValues: actual, failures: .unexpectedSuccessfulParse
          )
        }
        guard URLValues.diff(expectedResult, referenceResult).isEmpty else {
          return WPTConstructorTest.Result(
            testNumber: testNumber, testcase: testcase,
            propertyValues: actual, failures: .propertyMismatch
          )
        }
        // Success. Parsed with correct result.
        return nil
      })

    modelData.resultsState = .finished(mismatches)
    modelData.selectedItem = mismatches.first
  }

  fileprivate func runTestsWithWebURL() {
    guard let fileContents = parseSourceFileOrSetError() else { return }

    struct MismatchCollector: WPTConstructorTest.Harness {
      var mismatches: [WPTConstructorTest.Result] = []

      func parseURL(_ input: String, base: String?) -> URLValues? {
        return WebURL.JSModel(input, base: base)?.urlValues
      }
      mutating func reportTestResult(_ result: WPTConstructorTest.Result) {
        if !result.failures.isEmpty {
          mismatches.append(result)
        }
      }
    }

    modelData.resultsState = .running
    modelData.webURLRunnerQueue.async {
      var collector = MismatchCollector()
      collector.runTests(fileContents)
      DispatchQueue.main.async {
        modelData.resultsState = .finished(collector.mismatches)
        modelData.selectedItem = collector.mismatches.first
      }
    }
  }
}


// --------------------------------------------
// MARK: - MismatchInspector
// --------------------------------------------


/// A simple WPTConstructorTest.Result inspector.
/// Displays the test-case, the actual result, expected result, and a list of test failures.
///
fileprivate struct MismatchInspector: View {
  @Binding var testResult: WPTConstructorTest.Result
  @State var selecteditemDiff: [URLModelProperty] = []

  var body: some View {
    Group {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading) {
          HStack {
            Text("Input").bold()
            TextField("", text: .constant(testResult.testcase.input))
          }
          HStack {
            Text("Base").bold()
            TextField("", text: .constant(testResult.testcase.base ?? ""))
          }
        }

        WPTConstructorTestFailureBadges(testResult: .constant(testResult))

        URLForm(
          label: "Actual",
          values: .constant(testResult.propertyValues),
          flaggedKeys: $selecteditemDiff
        )
        URLForm(
          label: "Expected",
          values: .constant(testResult.testcase.expectedValues),
          flaggedKeys: $selecteditemDiff
        )
      }
    }
    .padding()
    #if !os(macOS)
      .navigationBarTitleDisplayMode(.large)
      .navigationBarTitle("Test \(testResult.testNumber)")
    #endif
    .onChange(of: testResult) { calculateDiff($0) }
    .onAppear { calculateDiff(testResult) }
  }

  private func calculateDiff(_ newTestResult: WPTConstructorTest.Result) {
    selecteditemDiff = URLValues.diff(newTestResult.propertyValues, newTestResult.testcase.expectedValues)
  }
}

/// A horizontal, scrollable list of test failures from a URL constructor test result.
///
fileprivate struct WPTConstructorTestFailureBadges: View {
  @Binding var testResult: WPTConstructorTest.Result

  var body: some View {
    ScrollView(.horizontal) {
      HStack {
        if testResult.failures.contains(.baseURLFailedToParse) {
          Badge("base URL failed to parse")
        }
        if testResult.failures.contains(.inputDidNotFailWhenUsedAsBaseURL) {
          Badge("input didn't fail as baseURL")
        }
        if testResult.failures.contains(.unexpectedFailureToParse) {
          Badge("Unexpected failure")
        }
        if testResult.failures.contains(.unexpectedSuccessfulParse) {
          Badge("Unexpected success")
        }
        if testResult.failures.contains(.propertyMismatch) {
          Badge("Property mismatch")
        }
        if testResult.failures.contains(.notIdempotent) {
          Badge("Not idempotent")
        }
      }.badgesHaveErrorStyle()
    }
  }
}
