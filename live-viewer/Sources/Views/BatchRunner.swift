import Foundation
import SwiftUI
import WebURL
import WebURLTestSupport

class BatchRunnerObjects: ObservableObject {
  static let kBatch_LastFile = "batch_lastfile"
  
  @Published var sourceFile: URL? = .none {
    didSet { UserDefaults.standard.set(try? sourceFile?.bookmarkData(), forKey: Self.kBatch_LastFile) }
  }
  
  @Published var resultsState: ResultsState? = .none {
    didSet { selectedItem = nil }
  }
  
  @Published var selectedItem: WPTConstructorTest.Result? = .none {
    didSet { selectedItemDiff = URLValues.diff(selectedItem?.propertyValues, selectedItem?.testcase.expectedValues) }
  }
  @Published var selectedItemDiff: [URLModelProperty] = []
  
  enum ResultsState {
    case parseError(Error)
    case running(AnyObject?)
    case finished([WPTConstructorTest.Result])
  }
  
  init() {
    if let bookmarkData = UserDefaults.standard.data(forKey: Self.kBatch_LastFile) {
      var isStale = false
      let resolvedURL = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
      if isStale { UserDefaults.standard.set(try? resolvedURL?.bookmarkData(), forKey: Self.kBatch_LastFile) }
      self.sourceFile = resolvedURL
    }
  }
}


struct BatchRunner: View {
  @ObservedObject var objects = BatchRunnerObjects()
  
  var body: some View {
    VStack {
      // File picker & actions.
      VStack {
        GroupBox {
          HStack {
            Spacer()
            Text(objects.sourceFile?.path ?? "No file selected")
            Button("Choose...") {
              let popup = NSOpenPanel()
              popup.allowsMultipleSelection = false
              popup.canChooseDirectories = false
              popup.canChooseFiles = true
              popup.begin { response in
                if response == .OK, let selectedFile = popup.url {
                  self.objects.sourceFile = selectedFile
                }
              }
            }
            Spacer()
          }.padding(.all, 8)
        }
        HStack {
          Spacer()
          Button("Test with WebURL") { runTestsWithWebURL() }
          Button("Verify using JSDOM") { checkWithReference() }
        }.disabled(objects.sourceFile == nil)
        VStack(alignment: .leading) {
          Text("- 'Test with WebURL' runs a full WPT URL constructor test.")
          Text("- 'Verify using JSDOM' parses the input and base strings and checks the property values. It is not a full constructor test.")
        }.foregroundColor(.secondary)
      }
      Divider()
      // Results.
      VStack {
        switch objects.resultsState {
        case .none:
          Text("No results to display").foregroundColor(.secondary)
        case .parseError(let error):
          Text("🔥 Failed to parse:\n \(error.localizedDescription)").foregroundColor(.red)
        case .running:
          Text("Running...").foregroundColor(.secondary)
        case .finished(let mismatches):
          if mismatches.isEmpty {
            Text("✅ No mismatches found").bold().foregroundColor(.green)
          } else {
            MismatchInspector(
              mismatches: mismatches,
              selectedItem: Binding(get: { objects.selectedItem }, set: { objects.selectedItem = $0 }),
              selecteditemDiff: Binding(readOnly: objects.selectedItemDiff)
            )
          }
        }
      }.padding(.top, 10)
    }
  }
  
  func parseSelectedConstructorFileOrSetError() -> [WPTConstructorTest.FileEntry]? {
    guard let selectedFileURL = objects.sourceFile else {
      objects.resultsState = nil
      return nil
    }
    do {
      return try JSONDecoder().decode([WPTConstructorTest.FileEntry].self, from: try Data(contentsOf: selectedFileURL))
    } catch {
      objects.resultsState = .parseError(error)
      return nil
    }
  }
  
  func checkWithReference() {
    guard let fileContents = parseSelectedConstructorFileOrSetError() else { return }
    
    let runner = JSDOMRunner.BatchRunner.run(
      each: fileContents,
      // Extract (input, base) pair from FileEntry.
      extractValues: { (entry: WPTConstructorTest.FileEntry) -> (String, String?)? in
        if case .testcase(let test) = entry {
          return (test.input, test.base)
        }
        return nil
      },
      // Check to see if the result is a mismatch.
      // This doesn't perform the entire range of checks that a URLConstructorTest requires.
      generateResult: { testNumber, testcase, actual -> WPTConstructorTest.Result? in
        guard case .testcase(let testcase) = testcase else {
          preconditionFailure("Should only see test cases here")
        }
        guard let referenceResult = actual else {
          if !testcase.failure {
            return WPTConstructorTest.Result(testNumber: testNumber, testcase: testcase,
                                             propertyValues: nil, failures: .unexpectedFailureToParse)
          }
          return nil
        }
        guard let expectedResult = testcase.expectedValues else {
          return WPTConstructorTest.Result(testNumber: testNumber, testcase: testcase,
                                           propertyValues: actual, failures: .unexpectedSuccessfulParse)
        }
        let diff = URLValues.diff(expectedResult, referenceResult)
        return diff.isEmpty ? nil : WPTConstructorTest.Result(testNumber: testNumber, testcase: testcase,
                                                              propertyValues: actual, failures: .propertyMismatch)
  
      // Send the results to the view.
      }, completion: { mismatches in
        objects.resultsState = .finished(mismatches)
        objects.selectedItem = mismatches.first
      })
      objects.resultsState = .running(runner)
  }
  
  
  func runTestsWithWebURL() {
    guard let fileContents = parseSelectedConstructorFileOrSetError() else { return }
    
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
    
    objects.resultsState = .running(nil)
    var collector = MismatchCollector()
    collector.runTests(fileContents)
    objects.resultsState = .finished(collector.mismatches)
    objects.selectedItem = collector.mismatches.first
  }
  
}

struct MismatchInspector: View {
  let mismatches: [WPTConstructorTest.Result]
  let selectedItem: Binding<WPTConstructorTest.Result?>
  let selecteditemDiff: Binding<[URLModelProperty]>
  
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // List.
      VStack(alignment: .center) {
        List(mismatches, id: \.self, selection: selectedItem) { entry in
          HStack(alignment: .center) {
            VStack(alignment: .leading) {
              Text("\(entry.testcase.input)").lineLimit(1)
              Text("\(entry.testcase.base ?? "")").lineLimit(1)
            }
            Spacer()
            Divider()
            Badge(String(entry.testNumber)).badgeColor(.yellow).badgeTextColor(.black)
          }
          
        }.frame(width: 200)
        
        Text("\(mismatches.count) mismatches").foregroundColor(.secondary)
      }
      
			// Inspector.
      VStack {
        if let selection = selectedItem.wrappedValue {
          VStack(alignment: .leading, spacing: 10) {
            
            VStack(alignment: .leading) {
              HStack() {
                Text("Input").bold()
                TextField("", text: Binding(readOnly: selection.testcase.input))
              }
              HStack {
                Text("Base").bold()
                TextField("", text: Binding(readOnly: selection.testcase.base))
              }
            }
            
            SubtestFailureBadges(results: Binding(readOnly: selection))
             
            URLForm(
              label: "Actual",
              model: Binding(readOnly: selection.propertyValues),
              badKeys: selecteditemDiff
            )
            URLForm(
              label: "Expected",
              model: Binding(readOnly: selection.testcase.expectedValues),
              badKeys: selecteditemDiff
            )
          }
        } else {
          Spacer()
          HStack {
            Spacer()
            Text("Select a result to inspect it").foregroundColor(.secondary)
            Spacer()
          }
          Spacer()
        }
      }
    }
  }
}

/// A horizontal, scrollable list of subtest failures from a URL constructor test result.
///
struct SubtestFailureBadges: View {
  @Binding var results: WPTConstructorTest.Result
  
  var body: some View {
    ScrollView(.horizontal) {
      HStack {
        if results.failures.contains(.baseURLFailedToParse) {
          Badge("base URL failed to parse")
        }
        if results.failures.contains(.inputDidNotFailWhenUsedAsBaseURL) {
          Badge("input didn't fail as baseURL")
        }
        if results.failures.contains(.unexpectedFailureToParse) {
          Badge("Unexpected failure")
        }
        if results.failures.contains(.unexpectedSuccessfulParse) {
          Badge("Unexpected success")
        }
        if results.failures.contains(.propertyMismatch) {
          Badge("Property mismatch")
        }
        if results.failures.contains(.notIdempotent) {
          Badge("Not idempotent")
        }
      }.badgeColor(.red).badgeTextColor(.black)
    }
  }
}
