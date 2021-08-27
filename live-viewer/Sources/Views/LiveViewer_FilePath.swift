import Combine
import SwiftUI
import WebURL
import WebURLTestSupport

class FilePathViewerObjects: ObservableObject {

  // Inputs.
  @Published var inputFilePath: String = ""
  @Published var inputFilePathFormat: FilePathFormat = .native
  @Published var pathToURLError: String? = nil
  @Published var inputURLString  = ""

  // (Path/URL String) -> WebURL.
  @Published var weburl: URLValues? = nil

  // WebURL -> Path.
  @Published var posixPath: Result<String, Error>? = nil
  @Published var windowsPath: Result<String, Error>? = nil
}

struct FilePathViewer: View {

  @ObservedObject fileprivate var objects = FilePathViewerObjects()
  @State fileprivate var source = Source.filepath

  enum Source: Equatable, Hashable {
    case filepath
    case url
  }

  var body: some View {
    VStack(spacing: 10) {

      Picker("Source", selection: $source.withModificationCallback(sourceChanged)) {
        Text("File path").tag(Source.filepath)
        Text("URL").tag(Source.url)
      }.pickerStyle(SegmentedPickerStyle())
       .frame(maxWidth: 200)

      // Source field. Create a URL from either:
      // - A file path (in a given format).
      // - A URL string.
      switch source {
      case .filepath:
        GroupBox(label: Text("URL from File Path")) {
          VStack(spacing: 8) {
            HStack(alignment: .center) {
              TextField("File path", text: $objects.inputFilePath)
                .textFieldStyle(PlainTextFieldStyle())
              Picker("Format", selection: $objects.inputFilePathFormat) {
                ForEach(FilePathFormat.allCases, id: \.self) {
                  Text(String(describing: $0))
                }
              }.pickerStyle(SegmentedPickerStyle())
               .frame(maxWidth: 200)
            }.padding([.leading, .trailing, .top], 3)
            Divider()
            HStack {
              if let error = objects.pathToURLError {
                Badge(error).badgeColor(.red).badgeTextColor(.white)
              } else {
                Text(objects.weburl?[.href] ?? "")
                  .foregroundColor(.secondary)
                  .contextMenu {
                    Button("Copy to clipboard") { copyToClipboard(objects.weburl?[.href] ?? "") }
                  }
              }
            }.padding(.bottom, 3)
          }
        }
      case .url:
        GroupBox(label: Text("URL from String")) {
          TextField("URL String", text: $objects.inputURLString)
            .padding(.all, 3)
            .textFieldStyle(PlainTextFieldStyle())
        }
      }

      // Info about the constructed URL.
      URLForm(
        label: "URL Info",
        model: .constant(self.objects.weburl),
        badKeys: .constant([])
      )

      // File path from URL.
      GroupBox(label: Text("File Path from URL")) {
        VStack(alignment: .leading) {
          ForEach(FilePathFormat.allCases, id: \.self) { style in
            VStack {

              HStack(alignment: .center) {
                Text(String(describing: style))
                  .bold()
                  .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
                // Note: These cannot be extracted in to subviews because the compiler can't handle
                // @Binding var pathOrError = Optional<Result<String, Error>>.none
                switch style {
                case .posix:
                  switch objects.posixPath {
                  case .none:
                    Text("No result").foregroundColor(.secondary).frame(alignment: .leading)
                  case .success(let path):
                    Text(path)
                      .frame(alignment: .leading)
                      .contextMenu {
                        Button("Copy to clipboard") { copyToClipboard(path) }
                      }
                  case .failure(let error):
                    Badge(String(describing: error)).badgeColor(.red).badgeTextColor(.white)
                  }

                case .windows:
                  switch objects.windowsPath {
                  case .none:
                    Text("No result").foregroundColor(.secondary).frame(alignment: .leading)
                  case .success(let path):
                    Text(path)
                      .frame(alignment: .leading)
                      .contextMenu {
                        Button("Copy to clipboard") { copyToClipboard(path) }
                      }
                  case .failure(let error):
                    Badge(String(describing: error)).badgeColor(.red).badgeTextColor(.white)
                  }

                default:
                  fatalError("Unknown path style")
                }
                Spacer()
              }.frame(height: 26, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)

              if style != FilePathFormat.allCases.last {
                Divider()
              }

            }
          }
        }.padding([.top, .bottom], 3)
      }
    }
    .onReceive(objects.$inputFilePath.combineLatest(objects.$inputFilePathFormat)) { (path, format)  in
			updateFromFilePath(path, format)
    }
    .onReceive(objects.$inputURLString) { urlString in
			updateFromURLString(urlString)
    }
  }
}

extension FilePathViewer {

  func sourceChanged() {
    switch source {
    case .filepath: updateFromFilePath(objects.inputFilePath, objects.inputFilePathFormat)
    case .url: updateFromURLString(objects.inputURLString)
    }
  }

  func updateFromFilePath(_ path: String, _ format: FilePathFormat) {
    let url: WebURL?
    do {
      url = try WebURL(filePath: path, format: format)
      objects.pathToURLError = nil
    } catch {
      url = nil
      objects.pathToURLError = String(describing: error)
    }
    updateURLInfoAndDerivedFilePaths(url)
  }

  func updateFromURLString(_ urlString: String) {
    updateURLInfoAndDerivedFilePaths(WebURL(urlString))
  }

  private func updateURLInfoAndDerivedFilePaths(_ url: WebURL?) {
    objects.weburl = url?.jsModel.urlValues
    self.objects.posixPath = url.map { url in
      Result {
        try String(decoding: WebURL.filePathBytes(from: url, format: .posix, nullTerminated: false), as: UTF8.self)
      }
    }
    self.objects.windowsPath = url.map { url in
      Result {
        try String(decoding: WebURL.filePathBytes(from: url, format: .windows, nullTerminated: false), as: UTF8.self)
      }
    }
  }
}


// MARK: - Helpers, Protocol conformances


extension FilePathFormat: CaseIterable, Identifiable {

  public static var allCases: [FilePathFormat] { [.posix, .windows] }

  public var id: String {
    description
  }
}

extension Binding {

  fileprivate func withModificationCallback(_ handler: @escaping () -> Void) -> Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { self.wrappedValue = $0; handler() }
    )
  }
}
