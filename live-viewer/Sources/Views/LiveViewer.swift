import SwiftUI
import WebURL
import WebURLTestSupport

class LiveViewerObjects: ObservableObject {
  // User inputs.
  @Published var urlString = ""
  @Published var baseString = "about:blank"
  // Results of parsing/diffing.
  @Published var weburl = AnnotatedURLValues()
  @Published var reference = AnnotatedURLValues()
  // JS runner.
  var jsRunner = JSDOMRunner()
}

struct AnnotatedURLValues {
  var values: URLValues? = nil
  var flaggedKeys: [URLModelProperty] = []
}

struct LiveViewer: View {
  @ObservedObject private var objects = LiveViewerObjects()

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

      GroupBox {
        VStack {
          TextField("URL String", text: $objects.urlString).padding([.leading, .trailing, .top], 3)
          Divider()
          TextField("Base", text: $objects.baseString).padding([.leading, .trailing, .bottom], 3)
        }.textFieldStyle(PlainTextFieldStyle())
      }

      URLForm(
        label: "WebURL (JS model)",
        model: self.$objects.weburl.values,
        badKeys: self.$objects.weburl.flaggedKeys
      )
      URLForm(
        label: "Reference result",
        model: self.$objects.reference.values,
        badKeys: self.$objects.reference.flaggedKeys
      )
    }
    .onReceive(objects.$urlString.combineLatest(objects.$baseString)) { (input, base) in

      let webURLValues = WebURL.JSModel(input, base: base)?.urlValues
      self.objects.jsRunner(input: input, base: base) { result in
        let referenceValues = try? result.get()
        let webURLReferenceDiff = URLValues.diff(webURLValues, referenceValues)
        self.objects.weburl = AnnotatedURLValues(
          values: webURLValues,
          flaggedKeys: webURLReferenceDiff
        )
        self.objects.reference = AnnotatedURLValues(
          values: referenceValues,
          flaggedKeys: webURLReferenceDiff
        )
      }
    }
  }

  func generateClipboardString() -> String {
    return """
      Inputs:
      {
         input: \(objects.urlString)
         base:  \(objects.baseString)
      }

      WebURL result:
      \(objects.weburl.values?.description ?? "<nil>")

      Reference result:
      \(objects.reference.values?.description ?? "<nil>")
      """
  }
}
