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

  init(label: String, values: Binding<AnnotatedURLValues>) {
    self.label = label
    self._values = values
  }

  init(label: String, values: Binding<URLValues?>, flaggedKeys: Binding<[URLModelProperty]>) {
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
            HStack(spacing: 10) {
              Text(property.name)
                .bold()
                .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
              Text(values.values.map { $0[property] ?? "(nil)" } ?? "(URL is nil)")
                .frame(alignment: .leading)
              Spacer()
            }
            .foregroundColor(values.flaggedKeys.contains(property) ? .red : nil)
          }
        }
      }
    }
  }
}
