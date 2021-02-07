import Foundation
import SwiftUI

import WebURLTestSupport

/*
 TODO:
 
 - [ ] Display errors so file can be fixed manually.
 - [ ] Offer re-reading and verifying selected file so changes can be checked.
 
 - [ ] Offer to write corrected file (? - kinda unsure about this. It's handy but I'm not sure I want this to be so easy).
 */


struct BatchRunner: View {
  
  var body: some View {
    Text("🚧 NYI 🚧")
      .padding(.all, 10)
  }
}

var activeGenerator: AnyObject?

func generateTestFile(inputFile: URL) throws {
  
  do {
    let testFileContents = try JSONDecoder().decode([URLConstructorTestFileEntry].self, from: try Data(contentsOf: inputFile))
    
    activeGenerator = JSDOMRunner.BatchRunner.run(each: testFileContents,
      extractValues: { (tfe: URLConstructorTestFileEntry) -> (String, String)? in
        if case .test(let test) = tfe {
          return (test.input, test.base)
        }
        return nil
      },
      generateResult: { _, testcase, actual -> (URLConstructorTest, URLModel?, [KeyPath<URLModel, String>])? in
        guard case .test(let testcase) = testcase else {
          preconditionFailure()
        }
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
  
