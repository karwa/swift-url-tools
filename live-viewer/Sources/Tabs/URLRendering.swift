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
import WebURL
import WebURLFoundationExtras

struct URLRendering: View {
  @Binding var modelData: ModelData
  @Environment(\.colorScheme) var systemColorScheme: ColorScheme

  enum Style: CaseIterable, Equatable, Hashable, Identifiable {
    case mono
    case colorful
    var id: Self { self }
  }

  struct ModelData {
    var urlString = ""
    var selectedStyle = Style.mono
    var renderedString = NSAttributedString()
  }
}


// --------------------------------------------
// MARK: - View Body.
// --------------------------------------------


extension URLRendering {


  var body: some View {
    VStack(spacing: 10) {
      DividedGroupBox(
        top: TextField("URL String", text: $modelData.urlString),
        bottom: styleSelector
      )
      .textFieldStyle(PlainTextFieldStyle())
      .disableAutocorrectAndCapitalization()

      NSAttributedStringView(attributedString: $modelData.renderedString)
    }
    .onChange(of: modelData.urlString)  { updateResults($0, style: modelData.selectedStyle) }
    .onChange(of: modelData.selectedStyle) { updateResults(modelData.urlString, style: $0) }
    .onChange(of: systemColorScheme) { _ in updateResults(modelData.urlString, style: modelData.selectedStyle) }
  }

  var styleSelector: some View {
    HStack {
      Spacer()
      Picker("Style", selection: $modelData.selectedStyle) {
          ForEach(Style.allCases) { Text(String(describing: $0)).tag($0) }
      }.pickerStyle(SegmentedPickerStyle()).frame(maxWidth: CGFloat(Style.allCases.count) * 100)
      Spacer()
    }
  }
}


// --------------------------------------------
// MARK: - Event Handlers.
// --------------------------------------------


extension URLRendering {

  fileprivate func updateResults(_ input: String, style: Style) {
    modelData.renderedString = WebURL(input).map {
      switch style {
      case .mono:
        return Style.Mono().render($0)
      case .colorful:
        return Style.Colorful().render($0)
      }
    } ?? NSAttributedString(string: "")
  }
}


// --------------------------------------------
// MARK: - Styles
// --------------------------------------------


#if !canImport(Cocoa)

  typealias NSFont = UIFont
  typealias NSColor = UIColor

  extension UIColor {

    static var textColor: UIColor {
      switch UITraitCollection.current.userInterfaceStyle {
      case .dark: return .white
      case .light: return .black
      case .unspecified: fallthrough
      @unknown default: return .gray
      }
    }

    func blended(withFraction fraction: CGFloat, of other: UIColor) -> UIColor? {
      var (r, g, b, a) = (0 as CGFloat, 0 as CGFloat, 0 as CGFloat, 0 as CGFloat)
      var (other_r, other_g, other_b, other_a) = (0 as CGFloat, 0 as CGFloat, 0 as CGFloat, 0 as CGFloat)
      guard
        self.getRed(&r, green: &g, blue: &b, alpha: &a),
        other.getRed(&other_r, green: &other_g, blue: &other_b, alpha: &other_a)
      else { return nil }
      return UIColor(
        red:   r * (1 - fraction) + (other_r * fraction),
        green: g * (1 - fraction) + (other_g * fraction),
        blue:  b * (1 - fraction) + (other_b * fraction),
        alpha: a * (1 - fraction) + (other_a * fraction)
      )
    }
  }

#endif


extension URLRendering.Style {

  struct Mono: WebURL.NSAttributedStringStyle {
    var regularFont = NSFont(name: "Baskerville", size: 42)!
    var fontSize = CGFloat(42.0)
    var textColor = NSColor.textColor

    enum Scale {
      // Scheme, UserInfo are all base font size.
      static var hostOrOpaquePath: CGFloat      { 1.30 }
      // Port is base font size.
      static var pathComponentMinimum: CGFloat  { 1.10 } // First component is 10% larger than base text, smaller than host.
      static var pathComponentIncrease: CGFloat { 0.75 } // Path goes up by 75% of base text along its length, for a total of 1.85x.
      static var pathComponentLast: CGFloat     { 0.25 } // Final component gets an additional 25% boost, for 2.1x base text.
      static var queryParmDelimiters: CGFloat { 1.25 }
      // Fragment is base font size.
    }

    func prepareFinalResult(_ result: NSMutableAttributedString, url: WebURL) {
      // If there is a host, trim everything before it.
      // Perhaps should be limited to HTTP/S URLs?
      if let hostStart = url.utf8.hostname?.startIndex {
        result.replaceCharacters(in: NSRange(location: 0, length: hostStart), with: "")
      }
    }

    func baseAttributes(_ url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: textColor.withAlphaComponent(0.35),
        .font: regularFont.withSize(fontSize)
      ]
    }

    func hostnameAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: textColor,
        .font: regularFont.withSize(fontSize * Scale.hostOrOpaquePath),
        .underlineStyle: NSNumber(value: NSUnderlineStyle.thick.rawValue),
        .underlineColor: textColor,
      ]
    }

    func pathAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      guard url.hasOpaquePath else { return nil }
      return [
        .foregroundColor: textColor.withAlphaComponent(0.7),
        .font: regularFont.withSize(fontSize * Scale.hostOrOpaquePath)
      ]
    }

    func pathComponentAttributes(
      number i: Int, of total: Int, index: WebURL.PathComponents.Index, url: WebURL
    ) -> [NSAttributedString.Key : Any]? {

      // If there is a trailing "/", allow the prior component to be styled as last component.
      var adjustedTotal = total
      if total > 1, url.pathComponents.last == "" {
        adjustedTotal -= 1
      }

      let isLast = (i + 1 == adjustedTotal)
      let fraction = Double(i + 1)/Double(adjustedTotal)
      let opacity = 0.40 + (fraction * fraction * 0.35) + (isLast ? 0.1 : 0)
      let size    = (fontSize * Scale.pathComponentMinimum)
                      + (fraction * fraction * (fontSize * Scale.pathComponentIncrease))
                      + (isLast ? fontSize * Scale.pathComponentLast : 0)
      return [
        .foregroundColor: textColor.withAlphaComponent(opacity),
        .font: regularFont.withSize(size)
      ]
    }

    func queryAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: textColor.withAlphaComponent(0.20),
        .font: regularFont.withSize(fontSize * Scale.queryParmDelimiters),
      ]
    }

//    func queryParamsAttributes(
//      number i: Int, of total: Int, index: LazilySplitQueryParameters<WebURL.UTF8View.SubSequence>.Index, url: WebURL
//    ) -> (key: [NSAttributedString.Key : Any]?, value: [NSAttributedString.Key : Any]?) {
//      (key: [
//        .foregroundColor: textColor.withAlphaComponent(0.70),
//        .font: regularFont.withSize(fontSize),
//      ], value: [
//        .foregroundColor: textColor.withAlphaComponent(0.50),
//        .font: regularFont.withSize(fontSize)
//      ])
//    }
  }
}

// Colorful style.

extension URLRendering.Style {

  struct Colorful: WebURL.NSAttributedStringStyle {
    var regularFont = NSFont(name: "HelveticaNeue-CondensedBlack", size: 42)!
    var monoFont = NSFont(name: "Courier-Bold", size: 42)!
    var fontSize = CGFloat(42.0)
    var textColor = NSColor.textColor

    enum Scale {
      // Scheme, UserInfo are all base font size.
      static var hostOrOpaquePath: CGFloat      { 1.30 }
      static var port: CGFloat                  { 0.80 }
      static var pathComponentMinimum: CGFloat  { 1.10 } // First component is 10% larger than base text, smaller than host.
      static var pathComponentIncrease: CGFloat { 0.75 } // Path goes up by 75% of base text along its length, for a total of 1.85x.
      static var pathComponentLast: CGFloat     { 0.25 } // Final component gets an additional 25% boost, for 2.1x base text.
      // Query, Fragment are all base font size.
    }

    func baseAttributes(_ url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: textColor,
        .font: regularFont.withSize(fontSize)
      ]
    }

    func schemeAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: url.scheme == "https" ? NSColor.systemGreen : NSColor.systemOrange
      ]
    }

    func usernameAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: NSColor.systemRed.withAlphaComponent(0.7),
        .strikethroughStyle: NSNumber(value: NSUnderlineStyle.thick.rawValue),
      ]
    }

    func passwordAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: NSColor.clear,
        .strokeColor: textColor.withAlphaComponent(0.7),
        .strokeWidth: 3.0,
        .strikethroughStyle: NSNumber(value: NSUnderlineStyle.thick.rawValue),
        .strikethroughColor: textColor.withAlphaComponent(0.7),
      ]
    }

    func hostnameAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      var isIP = false
      if case .ipv4Address = url._spis._utf8_host { isIP = true }
      if case .ipv6Address = url._spis._utf8_host { isIP = true }
      if isIP {
        return [
          .foregroundColor: NSColor.systemTeal,
          .font: monoFont.withSize(fontSize * Scale.hostOrOpaquePath)
        ]
      }
      return [
        .foregroundColor: NSColor.systemTeal,
        .font: regularFont.withSize(fontSize * Scale.hostOrOpaquePath),
        .underlineStyle: NSNumber(value: NSUnderlineStyle.thick.rawValue),
        .underlineColor: NSColor.systemYellow,
      ]
    }

    func portAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: NSColor.systemIndigo,
        .font: monoFont.withSize(fontSize * Scale.port),
      ]
    }

    func pathAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      if url.hasOpaquePath {
        return [
          .foregroundColor: NSColor.systemPurple,
          .font: regularFont.withSize(fontSize * Scale.hostOrOpaquePath)
        ]
      }
      return [
        .foregroundColor: NSColor.systemGray
      ]
    }

    func pathComponentAttributes(
      number i: Int, of total: Int, index: WebURL.PathComponents.Index, url: WebURL
    ) -> [NSAttributedString.Key : Any]? {

      // If there is a trailing "/", allow the prior component to be formatted as last component.
      var adjustedTotal = total
      if total > 1, url.pathComponents.last == "" {
        adjustedTotal -= 1
      }

      let isLast = (i + 1 == adjustedTotal)
      let fraction = Double(i + 1)/Double(adjustedTotal)
      let color = NSColor.systemGray.blended(withFraction: fraction, of: .systemPink)!
      let size    = (fontSize * Scale.pathComponentMinimum)
                    + (fraction * fraction * (fontSize * Scale.pathComponentIncrease))
                    + (isLast ? fontSize * Scale.pathComponentLast : 0)
      return [
        .foregroundColor: color,
        .font: regularFont.withSize(size)
      ]
    }

    func queryAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: NSColor.systemYellow
      ]
    }

//    func queryParamsAttributes(
//      number i: Int, of total: Int, index: LazilySplitQueryParameters<WebURL.UTF8View.SubSequence>.Index, url: WebURL
//    ) -> (
//      key: [NSAttributedString.Key : Any]?, value: [NSAttributedString.Key : Any]?
//    ) {
//      return (key: [
//        .foregroundColor: NSColor.systemOrange
//      ], value: [
//        .foregroundColor: NSColor.systemBrown
//      ])
//    }

    func fragmentAttributes(url: WebURL) -> [NSAttributedString.Key : Any]? {
      [
        .foregroundColor: NSColor.systemRed
      ]
    }
  }
}
