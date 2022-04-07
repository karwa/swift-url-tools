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

struct MainView: View {

  enum Tabs: Int, CaseIterable {
    case liveViewer
    case filePathViewer
    case batchProcessor
    case rendering
  }
  @State var selectedTab = Tabs.liveViewer

  // Model data for tabs.
  // We want the data to be owned by this parent view,
  // so that switching tabs doesn't clear the data.

  @State var liveViewerData = LiveViewer.ModelData()
  @State var filePathData = FilePathViewer.ModelData()
  @State var batchRunnerData = BatchRunner.ModelData()
  @State var renderingData = URLRendering.ModelData()

  var body: some View {
    ScrollView(.vertical) {
      Group {
        switch selectedTab {
        case .liveViewer: LiveViewer(modelData: $liveViewerData)
        case .filePathViewer: FilePathViewer(modelData: $filePathData)
        case .batchProcessor: BatchRunner(modelData: $batchRunnerData)
        case .rendering: URLRendering(modelData: $renderingData)
        }
      }.padding(16)

      // FIXME: Is there a way to add keyboard shortcuts in SwiftUI without creaing an interactive view?
      Button("Next Tab") { selectedTab = Tabs(rawValue: selectedTab.rawValue + 1) ?? Tabs.allCases.first! }
      .opacity(0)
      .keyboardShortcut("]", modifiers: [.command, .shift])
      Button("Previous Tab") { selectedTab = Tabs(rawValue: selectedTab.rawValue - 1) ?? Tabs.allCases.last! }
      .opacity(0)
      .keyboardShortcut("[", modifiers: [.command, .shift])


    }.toolbar {
      ToolbarItem(placement: .principal) {
        Picker("", selection: $selectedTab) {
          Text("Live").tag(Tabs.liveViewer)
          Text("File Paths").tag(Tabs.filePathViewer)
          Text("Batch").tag(Tabs.batchProcessor)
          Text("Render").tag(Tabs.rendering)
        }.pickerStyle(.segmented)
      }
    }
    #if !os(macOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}
