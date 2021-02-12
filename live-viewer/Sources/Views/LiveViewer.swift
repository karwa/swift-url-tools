import Combine
import SwiftUI
import WebURL
import WebURLTestSupport

class LiveViewerObjects: ObservableObject {
  @Published var urlString  = ""
  @Published var baseString = "about:blank"
  
  @Published var weburl: URLValues? = nil
  
  @Published var reference: URLValues? = nil
  @Published var differences: [KeyPath<URLValues, String>] = []
  
  @Published var parseWithFoundation = false
  @Published var foundationResult: URLValues? = nil
  @Published var foundationDifferences: [KeyPath<URLValues, String>] = []
  
  @Published var reparseWithFoundation = false
  @Published var reparseFoundationResult: URLValues? = nil
  @Published var reparsefoundationDifferences: [KeyPath<URLValues, String>] = []
  
  var jsRunner = JSDOMRunner()
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
          Button("Copy to clipboard") {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(self.generateClipboardString(), forType: .string)
          }
          Button("Show Foundation result") { self.objects.parseWithFoundation.toggle() }
          Button("Re-parse WebURL result with Foundation") { self.objects.reparseWithFoundation.toggle() }
        }
      
      GroupBox {
        VStack {
          TextField("URL String", text: $objects.urlString).padding([.leading, .trailing, .top], 3)
          Divider()
          TextField("Base", text: $objects.baseString).padding([.leading, .trailing, .bottom], 3)
        }.textFieldStyle(PlainTextFieldStyle())
      }
      URLForm(
        label: "WebURL",
        model: Binding(readOnly: self.objects.weburl), badKeys: self.$objects.differences
      )
      URLForm(
        label: "Reference result",
        model: Binding(readOnly: self.objects.reference), badKeys: self.$objects.differences
      )
      
      if objects.parseWithFoundation {
        URLForm(
          label: "NSURL (adjusted)",
          model: Binding(readOnly: self.objects.foundationResult),
          badKeys: self.$objects.foundationDifferences
        )
        Text("""
          Note: This is really just for curiosity or to compare with existing behaviour.
          NS/CFURL was never designed to match the model in the WHATWG spec.
          """).foregroundColor(.secondary)
      }
      
      if objects.reparseWithFoundation {
        URLForm(
          label: "NSURL (via WebURL)",
          model: Binding(readOnly: self.objects.reparseFoundationResult),
          badKeys: self.$objects.reparsefoundationDifferences
        )
      }
    }
    .onReceive(objects.$urlString.combineLatest(objects.$baseString, objects.$parseWithFoundation, objects.$reparseWithFoundation)) {
      (input, base, parseWithFoundation, reparseWithFoundation) in
      
      self.objects.weburl = WebURL(input, base: base)?.jsModel.urlValues
      self.objects.foundationResult =
        parseWithFoundation ? URL(string: base).flatMap { URL(string: input, relativeTo: $0)?.urlValues } : nil
      self.objects.reparseFoundationResult =
        reparseWithFoundation ? WebURL(input, base: base).flatMap { URL(string: $0.jsModel.href)?.urlValues } : nil
      self.objects.reparsefoundationDifferences =
        reparseWithFoundation ? URLValues.diff(self.objects.weburl, self.objects.reparseFoundationResult) : []
      
      self.objects.jsRunner(input: input, base: base) { result in
        self.objects.reference = try? result.get()
        self.objects.differences = URLValues.diff(self.objects.reference, self.objects.weburl)
        self.objects.foundationDifferences =
          parseWithFoundation ? URLValues.diff(self.objects.reference, self.objects.foundationResult) : []
      }
    }
  }
  
  func generateClipboardString() -> String {
  	return
      """
      inputs: {
         input: \(objects.urlString)
         base:  \(objects.baseString)
      }

      WebURL result: \(objects.weburl?.description ?? "<nil>")

      Reference result: \(objects.reference?.description ?? "<nil>")
      """
  }
}
