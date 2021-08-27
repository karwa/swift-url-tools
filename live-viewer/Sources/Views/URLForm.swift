import SwiftUI
import WebURLTestSupport

/// A view which displays the contents of a `URLValues` object.
/// It also has a label, and the ability to highlight particular properties as being "bad".
/// Quite thrilling.
///
struct URLForm: View {
  var label: String = ""
  @Binding var model: URLValues?
  @Binding var badKeys: [URLModelProperty]
 
  var body: some View {
    GroupBox(label: Text(label)) {
      VStack(alignment: .leading) {
        ForEach(URLModelProperty.allCases, id: \.self) { property in
          HStack {
            Text(property.name)
              .bold()
              .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
            Text(self.model.map { $0[property] ?? "(nil)" } ?? "(URL is nil)")
              .frame(alignment: .leading)
            Spacer()
          }.foregroundColor(self.badKeys.contains(property) ? .red : nil)
        }
      }
    }
  }
}
