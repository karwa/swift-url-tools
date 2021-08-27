import SwiftUI

/// A simple badge, consisting of text inside a rounded rectangle.
/// Use the `.badgeColor()` and `.badgeTextColor()` environment modifiers to customise the badge's appearance.
///
struct Badge: View {

  private var text: Binding<String>
  @Environment(\.badgeTextColor) private var textColor
  @Environment(\.badgeColor) private var badgeColor

  init(_ text: Binding<String>) {
    self.text = text
  }

  init(_ text: String) {
    self.init(.constant(text))
  }
  
  var body: some View {
    Text(text.wrappedValue)
      .bold().foregroundColor(textColor).padding(2)
      .background(RoundedRectangle(cornerRadius: 5).foregroundColor(badgeColor))
  }
}

private struct BadgeColorKey: EnvironmentKey {
  static let defaultValue = Color.black
}
private struct BadgeTextColorKey: EnvironmentKey {
  static let defaultValue = Color.white
}
private extension EnvironmentValues {
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
