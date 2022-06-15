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

import IDNA
import SwiftUI
import WebURLTestSupport

struct AnnotatedURLValues {
  var values: URLValues? = nil
  var flaggedKeys: [URLModelProperty] = []
}

/// A view which displays the contents of a `URLValues` object.
/// It also has a label, and the ability to highlight particular properties as being "bad".
/// Quite thrilling.
///
struct URLForm: View {
  let label: String
  @Binding var values: AnnotatedURLValues
  @Binding var showDecodedIDN: Bool

  init(
    label: String,
    values: Binding<AnnotatedURLValues>,
    showDecodedIDN: Binding<Bool> = .constant(false)
  ) {
    self.label = label
    self._values = values
    self._showDecodedIDN = showDecodedIDN
  }

  init(
    label: String,
    values: Binding<URLValues?>,
    flaggedKeys: Binding<[URLModelProperty]>
  ) {
    self.init(
      label: label,
      values: .constant(AnnotatedURLValues(values: values.wrappedValue, flaggedKeys: flaggedKeys.wrappedValue))
    )
  }

  init(label: String, values: Binding<URLValues?>) {
    self.init(label: label, values: values, flaggedKeys: .constant([]))
  }

  var body: some View {
    GroupBox(label: Text(label)) {
      ScrollView(.horizontal) {
        VStack(alignment: .leading) {
          ForEach(URLModelProperty.allCases, id: \.self) { property in
            row(
              name: property.name,
              value: values.values.map { $0[property] ?? "(nil)" } ?? "(URL is nil)"
            )
            .foregroundColor(values.flaggedKeys.contains(property) ? .red : nil)
          }
          if showDecodedIDN, let hostname = values.values?[.hostname] {
            row(name: "<IDNA>", value: decodeIDN(hostname) ?? "<Failed to decode>")
          }
        }
      }
    }
  }

  private func row(name: String, value: String) -> some View {
    HStack(spacing: 10) {
      Text(name)
        .bold()
        .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
      Text(value)
        .frame(alignment: .leading)
      Spacer()
    }
  }
}

private func decodeIDN(_ hostname: String) -> String? {

  var result = ""
  let success = IDNA.toUnicode(utf8: hostname.utf8) { label, needsDot in
    result.unicodeScalars += label
    if needsDot { result += "." }
    return true
  }
  return success ? result : nil
}
