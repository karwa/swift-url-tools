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

    var showDecodedIDN = true

    var runnerOperationID = 0
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
          Toggle("Show decoded IDN", isOn: $modelData.showDecodedIDN)
        }
      // Input field.
      DividedGroupBox(
        top: TextField("URL String", text: $modelData.urlString),
        bottom: TextField("Base", text: $modelData.baseString)
      )
      .textFieldStyle(PlainTextFieldStyle())
      .disableAutocorrectAndCapitalization()
      .urlKeyboardType()
      // Results.
      URLForm(label: "WebURL (JS model)", values: $modelData.weburlResult, showDecodedIDN: $modelData.showDecodedIDN)
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
    Task { await doUpdateResults(input, base) }
  }

  /// Calculates new `weburlResult` and `referenceResult` values from the given string and base URL string.
  /// The values are calculated asynchronously.
  ///
  @MainActor
  private func doUpdateResults(_ input: String, _ base: String) async {

    // Since we suspend and hop to the JSDOMRunner's executor, this function may be called re-entrantly.
    // Assign a unique ID to each Task, so the UI is only updated with the results of the latest Task.
    modelData.runnerOperationID &+= 1
    let thisOperationID = modelData.runnerOperationID

    let webURLValues = WebURL.JSModel(input, base: base)?.urlValues
    let referenceValues = await modelData.jsRunner.parse(input: input, base: base)

    guard modelData.runnerOperationID == thisOperationID else {
      return
    }
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
