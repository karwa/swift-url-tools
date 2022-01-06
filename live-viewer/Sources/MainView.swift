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

  enum Tabs {
    case liveViewer
    case filePathViewer
    case batchProcessor
  }
  @State var selectedTab = Tabs.liveViewer

  // Model data for tabs.
  // We want the data to be owned by this parent view,
  // so that switching tabs doesn't clear the data.

  @State var liveViewerData = LiveViewer.ModelData()
  @State var filePathData = FilePathViewer.ModelData()
  @State var batchRunnerData = BatchRunner.ModelData()

  var body: some View {
    ScrollView {
      Group {
        switch selectedTab {
        case .liveViewer: LiveViewer(modelData: $liveViewerData)
        case .filePathViewer: FilePathViewer(modelData: $filePathData)
        case .batchProcessor: BatchRunner(modelData: $batchRunnerData)
        }
      }.padding(16)
    }.toolbar {
      ToolbarItem(placement: .principal) {
        Picker("", selection: $selectedTab) {
          Text("Live").tag(Tabs.liveViewer)
          Text("File Paths").tag(Tabs.filePathViewer)
          Text("Batch").tag(Tabs.batchProcessor)
        }.pickerStyle(.segmented)
      }
    }
    #if !os(macOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}
