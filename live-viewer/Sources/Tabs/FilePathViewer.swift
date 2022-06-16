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

struct FilePathViewer: View {
  @State var selectedSource = SourceKind.filepath
  @Binding var modelData: ModelData

  enum SourceKind: Equatable, Hashable {
    case filepath
    case url
  }

  struct ModelData {
    var sourceFilePath = ""
    var sourceFilePathFormat = FilePathFormat.native
    var sourceURLString = ""
    // Step 1: Source File Path/URL String -> WebURL.
    var urlFromFilePathError = URLFromFilePathError?.some(.emptyInput)
    var fileURLValues = URLValues?.none
    // Step 2: WebURL -> File Path.
    var posixPathResult = Result<String, FilePathFromURLError>?.none
    var windowsPathResult = Result<String, FilePathFromURLError>?.none
  }
}


// --------------------------------------------
// MARK: - View Body.
// --------------------------------------------


extension FilePathViewer {

  var body: some View {
    VStack(spacing: 10) {
      Picker("Source", selection: $selectedSource) {
        Text("File path").tag(SourceKind.filepath)
        Text("URL").tag(SourceKind.url)
      }
      .pickerStyle(SegmentedPickerStyle())
      .frame(maxWidth: 200)

      // Input Field (depends on the selected source kind).
      inputField(selectedSource)

      // Step 1: Construct a URL from the file path/URL string.
      URLForm(label: "URL Info", values: $modelData.fileURLValues)

      // Step 2: Construct a file path from the URL created in Step 1.
      DividedGroupBox(
        label: Text("File Path from URL"),
        top: filePathFromURLRow($modelData.posixPathResult, format: .posix),
        bottom: filePathFromURLRow($modelData.windowsPathResult, format: .windows)
      )
    }
    .onChange(of: selectedSource) { sourceChanged(to: $0) }
    .onChange(of: modelData.sourceFilePath) { updateFromFilePath($0, modelData.sourceFilePathFormat) }
    .onChange(of: modelData.sourceFilePathFormat) { updateFromFilePath(modelData.sourceFilePath, $0) }
    .onChange(of: modelData.sourceURLString) { updateFromURLString($0) }
  }

  /// Returns the appropriate input field for the given source kind.
  ///
  @ViewBuilder
  private func inputField(_ sourceKind: SourceKind) -> some View {
    switch selectedSource {
    case .filepath:
      DividedGroupBox(
        label: {
          HStack {
            Text("URL from File Path")
            Spacer()
            Picker("Format", selection: $modelData.sourceFilePathFormat) {
              ForEach(FilePathFormat.allCases, id: \.self) { Text(String(describing: $0)) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 200)
          }.padding(.bottom, 2)
        },
        top: {
          TextField("File path", text: $modelData.sourceFilePath)
            .padding(.vertical, 2)
            .textFieldStyle(PlainTextFieldStyle())
            .disableAutocorrectAndCapitalization()
            .urlKeyboardType()  // Even though this is a file path, the URL keyboard is a bit nicer.
        },
        bottom: {
          if let error = modelData.urlFromFilePathError {
            Badge(error).badgesHaveErrorStyle()
          } else {
            Text(modelData.fileURLValues?[.href] ?? "")
              .foregroundColor(.secondary)
              .padding(.vertical, 2)
              .contextMenu {
                Button("Copy to clipboard") { copyToClipboard(modelData.fileURLValues?[.href] ?? "") }
              }
          }
        })
    case .url:
      GroupBox(label: Text("URL from String").padding(.bottom, 3)) {
        TextField("URL String", text: $modelData.sourceURLString)
          .padding(.horizontal, 6).padding(.vertical, 3)
          .textFieldStyle(PlainTextFieldStyle())
          .disableAutocorrectAndCapitalization()
          .urlKeyboardType()
      }
    }
  }

  /// Returns a row displaying the given FilePathFromURL result.
  ///
  @ViewBuilder
  private func filePathFromURLRow(
    _ resultData: Binding<Result<String, FilePathFromURLError>?>, format: FilePathFormat
  ) -> some View {
    HStack(spacing: 10) {
      Text(String(describing: format))
        .bold()
        .frame(minWidth: 100, maxWidth: 100, alignment: .trailing)
      Group {
        switch resultData.wrappedValue {
        case .none:
          Text("No result")
            .padding(.vertical, 2)
            .foregroundColor(.secondary)
        case .success(let path):
          Text(path)
            .padding(.vertical, 2)
            .contextMenu { Button("Copy to clipboard") { copyToClipboard(path) } }
        case .failure(let error):
            Badge(String(describing: error)).badgesHaveErrorStyle()
        }
      }.frame(alignment: .leading)
      Spacer()
    }.padding(.vertical, 4)
  }
}


// --------------------------------------------
// MARK: - Event Handlers.
// --------------------------------------------


extension FilePathViewer {

  /// Updates the view when the selected source is changed.
  ///
  fileprivate func sourceChanged(to newSource: SourceKind) {
    switch newSource {
    case .filepath: updateFromFilePath(modelData.sourceFilePath, modelData.sourceFilePathFormat)
    case .url: updateFromURLString(modelData.sourceURLString)
    }
  }

  /// Calculates new `fileURLValues`, `posixPathResult` and `windowsPathResult` values
  /// from the given file path string and format.
  ///
  fileprivate func updateFromFilePath(_ path: String, _ format: FilePathFormat) {
    let url: WebURL?
    do {
      url = try WebURL(filePath: path, format: format)
      modelData.urlFromFilePathError = nil
    } catch {
      url = nil
      modelData.urlFromFilePathError = (error as! URLFromFilePathError)
    }
    updateURLInfoAndDerivedFilePaths(url)
  }

  /// Calculates new `fileURLValues`, `posixPathResult` and `windowsPathResult` values
  /// from the given file URL string.
  ///
  fileprivate func updateFromURLString(_ urlString: String) {
    updateURLInfoAndDerivedFilePaths(WebURL(urlString))
  }

  /// Calculates new `fileURLValues`, `posixPathResult` and `windowsPathResult` values from the given WebURL.
  ///
  private func updateURLInfoAndDerivedFilePaths(_ url: WebURL?) {
    modelData.fileURLValues = url?.jsModel.urlValues
    self.modelData.posixPathResult = url.map { url in
      Result {
        try String(decoding: WebURL.binaryFilePath(from: url, format: .posix, nullTerminated: false), as: UTF8.self)
      }.mapError { $0 as! FilePathFromURLError }
    }
    self.modelData.windowsPathResult = url.map { url in
      Result {
        try String(decoding: WebURL.binaryFilePath(from: url, format: .windows, nullTerminated: false), as: UTF8.self)
      }.mapError { $0 as! FilePathFromURLError }
    }
  }
}


// --------------------------------------------
// MARK: - FilePathFormat Helpers.
// --------------------------------------------


extension FilePathFormat: CaseIterable, Identifiable {

  public static var allCases: [FilePathFormat] { [.posix, .windows] }

  public var id: String {
    description
  }
}
