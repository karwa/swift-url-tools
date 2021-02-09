import Foundation
import SwiftUI
import WebURL
import WebURLTestSupport

/// A URL parser test result.
///
/// Note that this isn't the same as a WPT constructor test result.
/// The WPT constructor tests include a bunch more checks (e .g. that the base URL must parse) that this object can't capture. 
///
struct URLParserResult: Equatable, Hashable {
  var test: URLConstructorTest
  var result: URLValues?
}

class BatchRunnerObjects: ObservableObject {
  @Published var sourceFile: URL? = .none
  @Published var resultsState: ResultsState? = .none
  @Published var selectedItem: URLParserResult? = .none
  
  enum ResultsState {
    case parseError(Error)
    case running(AnyObject)
    case finished([URLParserResult])
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
              selectedItem: Binding(get: { objects.selectedItem }, set: { objects.selectedItem = $0 })
            )
          }
        }
      }.padding(.top, 10)
    }
  }
  
  func parseSelectedConstructorFileOrSetError() -> [URLConstructorTestFileEntry]? {
    guard let selectedFileURL = objects.sourceFile else {
      objects.resultsState = nil
      return nil
    }
    do {
      return try JSONDecoder().decode([URLConstructorTestFileEntry].self, from: try Data(contentsOf: selectedFileURL))
    } catch {
      objects.resultsState = .parseError(error)
      return nil
    }
  }
  
  func checkWithReference() {
    guard let fileContents = parseSelectedConstructorFileOrSetError() else { return }
    let runner = JSDOMRunner.BatchRunner.run(each: fileContents,
      extractValues: { (entry: URLConstructorTestFileEntry) -> (String, String)? in
        if case .test(let test) = entry {
          return (test.input, test.base)
        }
        return nil
      },
      generateResult: { _, testcase, actual -> URLParserResult? in
        guard case .test(let testcase) = testcase else {
          preconditionFailure()
        }
        guard let referenceResult = actual else {
          if !testcase.failure { return .init(test: testcase, result: actual) }
          return nil
        }
        guard let expectedResult = testcase.expectedValues else {
          return .init(test: testcase, result: actual)
        }
        let diff = URLValues.diff(expectedResult, referenceResult)
        return diff.isEmpty ? nil : .init(test: testcase, result: actual)
        
      }, completion: { mismatches in
        objects.resultsState = .finished(mismatches)
      })
      objects.resultsState = .running(runner)
  }
  
  func runTestsWithWebURL() {
    guard let fileContents = parseSelectedConstructorFileOrSetError() else { return }
    
    // TODO
  }
  
}

struct MismatchInspector: View {
  let mismatches: [URLParserResult]
  var selectedItem: Binding<URLParserResult?>
  
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // List.
      VStack(alignment: .center) {
        List(mismatches, id: \.self, selection: selectedItem) { entry in
          VStack(alignment: .leading) {
            Text("Input: \(entry.test.input)").lineLimit(1)
            Text("Base: \(entry.test.base)").lineLimit(1)
          }.tag(0)
        }.frame(width: 200).frame(idealHeight: 100)
        
        Text("\(mismatches.count) mismatches").foregroundColor(.secondary)
      }
			// Inspector.
      VStack {
        if let selection = selectedItem.wrappedValue {
          VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading) {
              HStack() {
                Text("Input").bold()
                TextField("", text: Binding(readOnly: selection.test.input))
              }
              HStack {
                Text("Base").bold()
                TextField("", text: Binding(readOnly: selection.test.base))
              }
            }
            URLForm(
              label: "Expected",
              model: Binding(readOnly: selection.test.expectedValues),
              badKeys: Binding(readOnly: URLValues.diff(selection.test.expectedValues, selection.result))
            )
            URLForm(
              label: "Actual",
              model: Binding(readOnly: selection.result),
              badKeys: Binding(readOnly: URLValues.diff(selection.test.expectedValues, selection.result))
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
