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

extension View {

  /// Disables autocorrect and autocapitalization on all views contained within this view.
  ///
  func disableAutocorrectAndCapitalization() -> some View {
    self
      .disableAutocorrection(true)
      #if !os(macOS)
        .autocapitalization(.none)
      #endif
  }

  /// Use the software keyboard optimized for entering URLs.
  ///
  /// This disables some of the 'smart' features, such as smart dashes (e.g. 2x'-' -> em-dash),
  /// and makes certain characters such as the forward-slash easier to find.
  ///
  func urlKeyboardType() -> some View {
    #if os(macOS)
      return self
    #else
      return self.keyboardType(.URL)
    #endif
  }
}

extension View {

  /// Styles all `Badge`s contained within this view with a syle appropriate for displaying errors.
  ///
  func badgesHaveErrorStyle() -> some View {
    self.badgeColor(.red).badgeTextColor(.white)
  }
}
