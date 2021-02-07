import Foundation
import WebURLTestSupport

extension JSDOMRunner {
  final class BatchRunner<T> {

    static func runTests(
      _ testFileEntries: [URLConstructorTestFileEntry],
      test: @escaping (URLConstructorTest, JSDataURLModel?)->T?,
      completion: @escaping ([T])->Void
    ) -> AnyObject {
      let gen = BatchRunner(test: test, completion: completion)
      gen.runNextTest(testFileEntries[...])
      return gen
    }
    
    var results: [T]
    var jsRunner: JSDOMRunner
    let test: (URLConstructorTest, JSDataURLModel?) -> T?
    let completion: ([T]) -> Void
    
    private init(test: @escaping (URLConstructorTest, JSDataURLModel?) -> T?, completion: @escaping ([T]) -> Void) {
      self.results = []
      self.test = test
      self.completion = completion
      self.jsRunner = JSDOMRunner()
    }
    
    private func runNextTest(_ remaining: ArraySlice<URLConstructorTestFileEntry>) {
      var remaining = remaining
      guard let testcase = remaining.popFirst() else {
        completion(results) // Finished.
        return
      }
      guard case .test(let test) = testcase else {
        return runNextTest(remaining)
      }
      jsRunner(input: test.input, base: test.base) { [weak self] referenceResult in
        guard let self = self else { return }
        if let unexpectedResult = self.test(test, try? referenceResult.get()) {
          self.results.append(unexpectedResult)
        }
        return self.runNextTest(remaining)
      }
    }
  }
}




extension URLValues: URLModel {
  var scheme: String {
    self.protocol
  }
}


var activeGenerator: AnyObject?
  
func generateTestFile(inputFile: URL) throws {
  
  do {
    var testFileContents = try JSONDecoder().decode([URLConstructorTestFileEntry].self, from: try Data(contentsOf: inputFile))
    
    activeGenerator = TestGenerator.runTests(
      testFileContents,
      test: { testcase, actual -> (URLConstructorTest, URLModel?, [KeyPath<URLModel, String>])? in
        guard let referenceResult = actual else {
          if !testcase.failure { return (testcase, actual, []) }
          return nil
        }
        guard let expectedResult = testcase.expectedValues else {
          return (testcase, actual, [])
        }
        if expectedResult.unequalKeys(comparedTo: referenceResult).isEmpty == false {
					return (testcase, actual, expectedResult.unequalKeys(comparedTo: referenceResult))
        }
        return nil
        
      }, completion: { results in
       
        for (test, result, keys) in results {
          print("---------------------------")
          print("Failed!")
          print("Expected: \(test)")
          print("Actual: \(result)")
          
          keys.forEach {
            print("key ----")
            print("Expected: \(test.expectedValues?[keyPath: $0])")
            print("Actual: \(result?[keyPath: $0])")
          }
        }
      })
    
  } catch {
    print(error)
  }
}
  
