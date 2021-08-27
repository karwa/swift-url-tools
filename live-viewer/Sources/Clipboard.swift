import SwiftUI

func copyToClipboard(_ string: String) {
  let pasteboard = NSPasteboard.general
  pasteboard.declareTypes([.string], owner: nil)
  pasteboard.setString(string, forType: .string)
}
