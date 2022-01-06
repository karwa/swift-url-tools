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

/// A simple badge, consisting of text inside a rounded rectangle.
/// Use the `.badgeColor()` and `.badgeTextColor()` environment modifiers to customise the badge's appearance.
///
struct Badge: View {
  @Binding private var text: String
  @Environment(\.badgeTextColor) private var textColor
  @Environment(\.badgeColor) private var badgeColor

  init(_ text: Binding<String>) {
    self._text = text
  }

  init(_ text: String) {
    self.init(.constant(text))
  }

  init<Value>(_ value: Value) where Value: CustomStringConvertible {
    self.init(value.description)
  }

  var body: some View {
    Text($text.wrappedValue)
      .bold().foregroundColor(textColor).padding(.vertical, 2).padding(.horizontal, 5)
      .background(RoundedRectangle(cornerRadius: 5).foregroundColor(badgeColor))
      .lineLimit(nil)
  }
}


// --------------------------------------------
// MARK: - Badge Styling Modifiers.
// --------------------------------------------


extension EnvironmentValues {

  private struct BadgeColorKey: EnvironmentKey {
    static let defaultValue = Color.black
  }

  fileprivate var badgeColor: Color {
    get { self[BadgeColorKey.self] }
    set { self[BadgeColorKey.self] = newValue }
  }

  private struct BadgeTextColorKey: EnvironmentKey {
    static let defaultValue = Color.white
  }

  fileprivate var badgeTextColor: Color {
    get { self[BadgeTextColorKey.self] }
    set { self[BadgeTextColorKey.self] = newValue }
  }
}

extension View {

  /// Styles all `Badge`s contained within this view with the given background color.
  ///
  func badgeColor(_ newColor: Color) -> some View {
    environment(\.badgeColor, newColor)
  }

  /// Styles all `Badge`s contained within this view with the given text color.
  ///
  func badgeTextColor(_ newColor: Color) -> some View {
    environment(\.badgeTextColor, newColor)
  }
}
