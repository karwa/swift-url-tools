import SwiftUI

/// A simple badge, consisting of text inside a rounded rectangle.
/// Use the `.badgeColor()` and `.badgeTextColor()` environment modifiers to customise the badge's appearance.
///
struct Badge: View {
  @State var text: String
  @Environment(\.badgeTextColor) var _textColor
  @Environment(\.badgeColor) var _badgeColor
  
  var body: some View {
    Text(text)
      .bold().foregroundColor(_textColor).padding(2)
      .background(RoundedRectangle(cornerRadius: 5).foregroundColor(_badgeColor))
  }
}

private struct BadgeColorKey: EnvironmentKey {
  static let defaultValue = Color.black
}
private struct BadgeTextColorKey: EnvironmentKey {
  static let defaultValue = Color.white
}
extension EnvironmentValues {
  var badgeColor: Color {
    get { self[BadgeColorKey.self] }
    set { self[BadgeColorKey.self] = newValue }
  }
  var badgeTextColor: Color {
    get { self[BadgeTextColorKey.self] }
    set { self[BadgeTextColorKey.self] = newValue }
  }
}
extension View {
  func badgeColor(_ newColor: Color) -> some View {
    environment(\.badgeColor, newColor)
  }
  func badgeTextColor(_ newColor: Color) -> some View {
    environment(\.badgeTextColor, newColor)
  }
}
