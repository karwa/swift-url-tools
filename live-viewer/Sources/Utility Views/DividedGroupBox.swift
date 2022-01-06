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

/// A GroupBox containing a top and bottom view, separated by a divider.
///
struct DividedGroupBox<Label: View, Top: View, Bottom: View>: View {
  var label: Label
  var top: Top
  var bottom: Bottom

  init(label: Label, top: Top, bottom: Bottom) {
    self.label = label
    self.top = top
    self.bottom = bottom
  }

  init(@ViewBuilder label: () -> Label, @ViewBuilder top: () -> Top, @ViewBuilder bottom: () -> Bottom) {
    self.init(label: label(), top: top(), bottom: bottom())
  }

  var body: some View {

    // MacOS has padding around the divider, but not around the GroupBox contents.
    // This means we need to add top padding to the top view, and bottom padding to the bottom view.
    //
    // ┌─Group Box───────────┐
    // │┌───────────────────┐│
    // ││                   ││
    // ││    Top Content    ││
    // ││                   ││
    // │├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┤│
    // ││  System Padding   ││
    // │├───────────────────┤│ <-- divider
    // ││  System Padding   ││
    // │├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┤│
    // ││                   ││
    // ││    Btm Content    ││
    // ││                   ││
    // │└───────────────────┘│
    // └─────────────────────┘
    //
    // iOS has a lot of padding around the GroupBox contents, but not as much around the divider.
    // This means we need to add bottom padding to the top view, and top padding to the bottom view.
    //
    // ┌─Group Box───────────┐
    // │   System Padding    │
    // │┌───────────────────┐│
    // ││                   ││
    // ││    Top Content    ││
    // ││                   ││
    // │├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┤│
    // │├───────────────────┤│ <-- divider
    // │├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┤│
    // ││                   ││
    // ││    Btm Content    ││
    // ││                   ││
    // │└───────────────────┘│
    // │   System Padding    │
    // └─────────────────────┘

    GroupBox(label: label) {
      VStack(spacing: 8) {
        top
          .padding(.horizontal, 6)
          #if os(macOS)
            .padding(.top, 3)
          #else
            .padding(.bottom, 6)
          #endif
        Divider()
        bottom
          .padding(.horizontal, 6)
          #if os(macOS)
            .padding(.bottom, 3)
          #else
            .padding(.top, 6)
          #endif
      }
    }
  }
}

extension DividedGroupBox where Label == EmptyView {

  init(top: Top, bottom: Bottom) {
    self.label = EmptyView()
    self.top = top
    self.bottom = bottom
  }

  init(@ViewBuilder top: () -> Top, @ViewBuilder bottom: () -> Bottom) {
    self.init(top: top(), bottom: bottom())
  }
}
