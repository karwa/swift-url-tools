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

@main
struct LiveURLViewerApp: App {
  var body: some Scene {
    #if os(macOS)
      WindowGroup {
        MainView()  // macOS can't handle the navigation view; SwiftUI crashes with out-of-bounds array access.
      }.windowToolbarStyle(.unified(showsTitle: false))
    #else
      WindowGroup {
        NavigationView {
          MainView()
        }
      }
    #endif
  }
}
