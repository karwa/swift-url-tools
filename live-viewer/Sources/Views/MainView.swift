import SwiftUI

struct MainView: View {
  
  enum Tabs {
    case liveViewer
    case batchProcessor
  }
  @State var selectedTab = Tabs.liveViewer
  
  let liveView = LiveViewer()
  let batchRunner = BatchRunner()
  
  var body: some View {
    VStack {
      // Header.
      VStack {
        HStack {
          Spacer()
          Picker("", selection: $selectedTab) {
            Text("Live").tag(Tabs.liveViewer)
            Text("Batch").tag(Tabs.batchProcessor)
          }
          .pickerStyle(SegmentedPickerStyle())
          Spacer()
        }.padding(.top, 8).padding(.horizontal, 100)
        Divider()
      }.frame(height: 42)
      // Content.
      switch selectedTab {
      case .liveViewer: liveView.padding(16)
      case .batchProcessor: batchRunner.padding(16)
      }
    }
  }
}
