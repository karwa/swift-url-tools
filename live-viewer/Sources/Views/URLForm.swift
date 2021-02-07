import SwiftUI

/// A form which displays information about type conforming to `URLModel`.
/// It also has a label, and the ability to highlight particular properties as being "bad". Quite thrilling.
///
struct URLForm<Model: URLModel>: View {
  var label: String = ""
  @Binding var model: Model?
  @Binding var badKeys: [KeyPath<URLModel, String>]
 
  var body: some View {
    GroupBox(label: Text(label)) {
      VStack {
        ForEach([
          ("href", \URLModel.href),
          ("protocol", \URLModel.scheme),
          ("hostname", \URLModel.hostname),
          ("port", \URLModel.port),
          ("username", \URLModel.username),
          ("password", \URLModel.password),
          ("pathname", \URLModel.pathname),
          ("search", \URLModel.search),
          ("hash", \URLModel.hash),
        ], id: \.1) { (item: (String, KeyPath<URLModel, String>)) in
          HStack {
            Text(item.0)
              .bold()
              .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
            let description = self.model.map { $0[keyPath: item.1] } ?? "<URL is nil>"
            Text(description)
              .frame(alignment: .leading)
            Spacer()
          }.foregroundColor(self.badKeys.contains(item.1) ? .red : nil)
        }
      }
    }
  }
}
