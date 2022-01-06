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

struct LiveViewer: View {
  @Binding var modelData: ModelData

  struct ModelData {
    var urlString = ""
    var baseString = "about:blank"
    var weburlResult = AnnotatedURLValues()
    var referenceResult = AnnotatedURLValues()

    var runnerActionID = 0
    var jsRunner = JSDOMRunner()
  }
}


// --------------------------------------------
// MARK: - View Body.
// --------------------------------------------


extension LiveViewer {

  var body: some View {
    VStack(spacing: 10) {
      Image("logo")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .padding(8)
        .frame(height: 50, alignment: .center)
        .contextMenu {
          Button("Copy to clipboard") { copyToClipboard(generateClipboardString()) }
        }
      // Input field.
      DividedGroupBox(
        top: TextField("URL String", text: $modelData.urlString),
        bottom: TextField("Base", text: $modelData.baseString)
      )
      .textFieldStyle(PlainTextFieldStyle())
      .disableAutocorrectAndCapitalization()
      // Results.
      URLForm(label: "WebURL (JS model)", values: $modelData.weburlResult)
      URLForm(label: "Reference result", values: $modelData.referenceResult)
    }
    .onChange(of: modelData.urlString)  { updateResults($0, modelData.baseString) }
    .onChange(of: modelData.baseString) { updateResults(modelData.urlString, $0)  }
  }
}


// --------------------------------------------
// MARK: - Event Handlers.
// --------------------------------------------


extension LiveViewer {

  /// Calculates new `weburlResult` and `referenceResult` values from the given string and base URL string.
  /// The values are calculated asynchronously.
  ///
  fileprivate func updateResults(_ input: String, _ base: String) {

    let webURLValues = WebURL.JSModel(input, base: base)?.urlValues

    // This calculation is re-entrant: we may submit new actions to the runner
    // while others are still in-flight, and they may arrive out of order.
    modelData.runnerActionID &+= 1
    let reentrantActionID = modelData.runnerActionID
    modelData.jsRunner(input: input, base: base) { result in
      // Ensure we only update the display with the results for the latest request.
      guard modelData.runnerActionID == reentrantActionID else {
        return
      }
      let referenceValues = try? result.get()
      let webURLReferenceDiff = URLValues.diff(webURLValues, referenceValues)
      modelData.weburlResult = AnnotatedURLValues(
        values: webURLValues,
        flaggedKeys: webURLReferenceDiff
      )
      modelData.referenceResult = AnnotatedURLValues(
        values: referenceValues,
        flaggedKeys: webURLReferenceDiff
      )
    }
  }
}


// --------------------------------------------
// MARK: - Utilities.
// --------------------------------------------


extension LiveViewer {

  /// Produces a textual description of this view's model data, for copying to the clipboard.
  ///
  fileprivate func generateClipboardString() -> String {
    return """
      Inputs:
      {
         input: \(modelData.urlString)
         base:  \(modelData.baseString)
      }

      WebURL result:
      \(modelData.weburlResult.values?.description ?? "<nil>")

      Reference result:
      \(modelData.referenceResult.values?.description ?? "<nil>")
      """
  }
}
