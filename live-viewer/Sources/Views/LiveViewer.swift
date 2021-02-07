import SwiftUI
import Combine
import WebURL

class LiveViewerObjects: ObservableObject {
  @Published var urlString  = ""
  @Published var baseString = "about:blank"
  
  @Published var weburl: WebURL.JSModel? = nil
  @Published var referenceResult: JSDataURLModel? = nil
  @Published var differences: [KeyPath<URLModel, String>] = []
  
  @Published var showNSURL = false
  @Published var foundationResult: FoundationURLModel? = nil
  @Published var foundationDifferences: [KeyPath<URLModel, String>] = []
  
  var jsRunner = JSDOMRunner()
}

struct LiveViewer: View {
  @ObservedObject private var objects = LiveViewerObjects()
  
  var body: some View {
    VStack {
      Image("logo")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: 50, alignment: .center)
        .contextMenu(menuItems: {
          Button("Toggle NSURL") { self.objects.showNSURL.toggle() }
          Button("Thing!") {
            let o = NSOpenPanel()
            o.begin { response in
              if response == .OK, let selectedFile = o.url {
                try? generateTestFile(inputFile: selectedFile)
              }
            }
          }
        })
      
      GroupBox {
        VStack {
          TextField("URL String", text: $objects.urlString)
          TextField("Base", text: $objects.baseString)
        }
      }.padding([.leading, .trailing], 10)
      
      URLForm(label: "WebURL", model: self.$objects.weburl, badKeys: self.$objects.differences)
      	.padding(10)
            
      URLForm(label: "Reference result", model: self.$objects.referenceResult, badKeys: self.$objects.differences)
        .padding(10)
        .padding(.bottom, 10)
      
      if objects.showNSURL {
        URLForm(label: "NSURL (adjusted)", model: self.$objects.foundationResult, badKeys: self.$objects.foundationDifferences)
          .padding(10)
          .padding(.bottom, 10)
      }
      
    }.onReceive(objects.$urlString.combineLatest(objects.$baseString, objects.$showNSURL)) { (url, base, showNSURL) in
      self.objects.weburl = WebURL(url, base: base)?.jsModel
      
      self.objects.jsRunner(input: url, base: base) { result in
        self.objects.referenceResult = try? result.get()
        switch (self.objects.referenceResult, self.objects.weburl) {
        case (.none, .none):
          self.objects.differences = []
        case (.some, .none), (.none, .some):
          self.objects.differences = allURLModelKeypaths
        case (.some(let ref), .some(let web)):
          self.objects.differences = web.unequalKeys(comparedTo: ref)
        }
        // Foundation (kinda).
        if showNSURL {
          self.objects.foundationResult = URL(string: base)
            .flatMap { URL(string: url, relativeTo: $0) }
            .map { FoundationURLModel(url: $0) }
          switch (self.objects.referenceResult, self.objects.foundationResult) {
          case (.none, .none):
            self.objects.foundationDifferences = []
          case (.some, .none), (.none, .some):
            self.objects.foundationDifferences = allURLModelKeypaths
          case (.some(let ref), .some(let web)):
            self.objects.foundationDifferences = web.unequalKeys(comparedTo: ref)
          }
        } else {
          self.objects.foundationResult = nil
          self.objects.foundationDifferences = []
        }
      }
    }
  }
}

