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

import Foundation
import SwiftUI

struct NSAttributedStringView: View {

  @Binding var attributedString: NSAttributedString
  @State private var measuredSize: CGSize = .zero

  var body: some View {
    Bridge(attributedString: $attributedString, measuredSize: $measuredSize)
      .frame(minHeight: measuredSize.height)
  }
}

#if canImport(Cocoa)

  import Cocoa

  extension NSAttributedStringView {

    private struct Bridge: NSViewRepresentable {

      @Binding fileprivate var attributedString: NSAttributedString
      @Binding fileprivate var measuredSize: CGSize

      func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        textView.textStorage?.setAttributedString(attributedString)
        textView.sizeToFit()
        DispatchQueue.main.async { measuredSize = textView.frame.size }
        return textView
      }

      func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.textStorage?.setAttributedString(attributedString)
        nsView.sizeToFit()
        DispatchQueue.main.async { measuredSize = nsView.frame.size }
      }
    }
  }

#elseif canImport(UIKit)

  import UIKit

  extension NSAttributedStringView {

    private struct Bridge: UIViewRepresentable {

      @Binding fileprivate var attributedString: NSAttributedString
      @Binding fileprivate var measuredSize: CGSize

      /// A UILabel which invokes a callback when its size changes.
      ///
      /// SwiftUI does not call `UIViewRepresentable.updateUIView` when the size changes (e.g. from rotation).
      /// This subclass ensures the bridge still re-measures the label's size.
      ///
      private class ResizeReportingUILabel: UILabel {
        var lastSuperviewSize: CGSize? = .none
        var onSuperviewSizeChanged: Optional<@MainActor (UILabel) -> Void> = .none

        override func didMoveToWindow() {
          super.didMoveToWindow()
          lastSuperviewSize = nil
          Task { @MainActor in onSuperviewSizeChanged?(self) }
        }

        override func layoutSubviews() {
          if superview?.frame.size != lastSuperviewSize {
            lastSuperviewSize = superview?.frame.size
            onSuperviewSizeChanged?(self)
          }
          super.layoutSubviews()
        }
      }

      func makeUIView(context: Context) -> UILabel {
        let label = ResizeReportingUILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        label.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
        label.backgroundColor = .clear
        // allow .attributedText to be set by the first update.

        label.onSuperviewSizeChanged = { label in
          // Available size changed. Re-measure the label.
          let widthToFit = label.superview?.frame.width ?? label.frame.width
          let size = label.sizeThatFits(CGSize(width: widthToFit, height: CGFloat.infinity))
          measuredSize = size
        }
        return label
      }

      func updateUIView(_ label: UILabel, context: Context) {
        guard label.attributedText != attributedString else { return }
        label.attributedText = attributedString

        // Don't trigger a deferred update if we're not attached to a window;
        // the size we measure isn't going to be meaningful, and we'll clobber the initial update.
        guard label.window != nil else { return }

        // We can't update SwiftUI state here, so defer the update.
        let widthToFit = label.superview?.frame.width ?? label.frame.width
        let size = label.sizeThatFits(CGSize(width: widthToFit, height: CGFloat.infinity))
        Task { @MainActor in measuredSize = size }
      }
    }
  }

#endif
