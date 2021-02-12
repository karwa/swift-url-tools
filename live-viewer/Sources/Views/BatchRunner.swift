import Foundation
import SwiftUI
import WebURL
import WebURLTestSupport

class BatchRunnerObjects: ObservableObject {
  @Published var sourceFile: URL? = .none
  
  @Published var resultsState: ResultsState? = .none {
    didSet { selectedItem = nil }
  }
  
  @Published var selectedItem: URLConstructorTest.Result? = .none {
    didSet { selectedItemDiff = URLValues.diff(selectedItem?.propertyValues, selectedItem?.testcase.expectedValues) }
  }
  @Published var selectedItemDiff: [KeyPath<URLValues, String>] = []
  
  enum ResultsState {
    case parseError(Error)
    case running(AnyObject?)
    case finished([URLConstructorTest.Result])
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
        Text("""
          - 'Test with WebURL' runs a full WPT URL constructor test.
          - 'Verify using JSDOM' parses input against base and checks if the values match what was expected (or that it fails as expected). It is not a full WPT constructor test.
          """).foregroundColor(.secondary)
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
            Text("✅ No mismatches found").foregroundColor(.green)
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
  
  func parseSelectedConstructorFileOrSetError() -> [URLConstructorTest.FileEntry]? {
    guard let selectedFileURL = objects.sourceFile else {
      objects.resultsState = nil
      return nil
    }
    do {
      return try JSONDecoder().decode([URLConstructorTest.FileEntry].self, from: try Data(contentsOf: selectedFileURL))
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
      extractValues: { (entry: URLConstructorTest.FileEntry) -> (String, String)? in
        if case .testcase(let test) = entry {
          return (test.input, test.base)
        }
        return nil
      },
      // Check to see if the result is a mismatch.
      // This doesn't perform the entire range of checks that a URLConstructorTest requires.
      generateResult: { testNumber, testcase, actual -> URLConstructorTest.Result? in
        guard case .testcase(let testcase) = testcase else {
          preconditionFailure("Should only see test cases here")
        }
        guard let referenceResult = actual else {
          if !testcase.failure {
            return URLConstructorTest.Result(testNumber: testNumber, testcase: testcase,
                                             propertyValues: nil, failures: .unexpectedFailureToParse)
          }
          return nil
        }
        guard let expectedResult = testcase.expectedValues else {
          return URLConstructorTest.Result(testNumber: testNumber, testcase: testcase,
                                           propertyValues: actual, failures: .unexpectedSuccessfulParse)
        }
        let diff = URLValues.diff(expectedResult, referenceResult)
        return diff.isEmpty ? nil : URLConstructorTest.Result(testNumber: testNumber, testcase: testcase,
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
    
    struct MismatchCollector: URLConstructorTest.Harness {
      var mismatches: [URLConstructorTest.Result] = []
      
      func parseURL(_ input: String, base: String?) -> URLValues? {
        return WebURL(input, base: base)?.jsModel.urlValues
      }
      mutating func reportTestResult(_ result: URLConstructorTest.Result) {
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
  let mismatches: [URLConstructorTest.Result]
  let selectedItem: Binding<URLConstructorTest.Result?>
  let selecteditemDiff: Binding<[KeyPath<URLValues, String>]>
  
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // List.
      VStack(alignment: .center) {
        List(mismatches, id: \.self, selection: selectedItem) { entry in
          
          HStack(alignment: .center) {
            VStack(alignment: .leading) {
              Text("\(entry.testcase.input)").lineLimit(1)
              Text("\(entry.testcase.base)").lineLimit(1)
            }
            Spacer()
            Divider()
            Text(String(entry.testNumber))
              .bold().foregroundColor(.black).padding(2)
              .background(RoundedRectangle(cornerRadius: 5).foregroundColor(.yellow))
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
