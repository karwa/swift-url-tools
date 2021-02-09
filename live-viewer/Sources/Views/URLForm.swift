import SwiftUI
import WebURLTestSupport

/// A view which displays the contents of a `URLValues` object.
/// It also has a label, and the ability to highlight particular properties as being "bad".
/// Quite thrilling.
///
struct URLForm: View {
  var label: String = ""
  @Binding var model: URLValues?
  @Binding var badKeys: [KeyPath<URLValues, String>]
 
  var body: some View {
    GroupBox(label: Text(label)) {
      VStack(alignment: .leading) {
        ForEach(URLValues.allTestableURLProperties, id: \.keyPath) { property in
          HStack {
            Text(property.name)
              .bold()
              .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
            let description = self.model.map { $0[keyPath: property.keyPath] } ?? "<URL is nil>"
            Text(description)
              .frame(alignment: .leading)
            Spacer()
          }.foregroundColor(self.badKeys.contains(property.keyPath) ? .red : nil)
        }
      }
    }
  }
}

extension Binding {
  
  init(readOnly value: Value) {
    self.init(get: { value }, set: { _ in })
  }
}
