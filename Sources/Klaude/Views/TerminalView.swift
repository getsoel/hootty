import SwiftUI
import AppKit

struct TerminalView: NSViewRepresentable {
    let session: PTYSession

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .black
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isRichText = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .white
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.renderedCount = 0

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let allSegments = session.segments
        let rendered = coordinator.renderedCount

        guard allSegments.count > rendered else { return }

        let newSegments = allSegments[rendered...]
        guard let textView = coordinator.textView,
              let storage = textView.textStorage else { return }

        storage.beginEditing()
        for segment in newSegments {
            let attrs = segment.style.nsAttributes
            let attrStr = NSAttributedString(string: segment.text, attributes: attrs)
            storage.append(attrStr)
        }
        storage.endEditing()

        coordinator.renderedCount = allSegments.count

        // Scroll to bottom
        textView.scrollToEndOfDocument(nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var textView: NSTextView?
        var renderedCount = 0
    }
}

// MARK: - ANSIStyle.Color → NSColor (direct, no SwiftUI.Color round-trip)

extension ANSIStyle.Color {
    var nsColor: NSColor? {
        switch self {
        case .default:
            return nil
        case .standard(let n):
            return Self.standardNSColor(n)
        case .palette(let n):
            if n < 16 {
                return Self.standardNSColor(n)
            } else if n < 232 {
                // 6x6x6 color cube: 16 + 36*r + 6*g + b
                let idx = Int(n) - 16
                let r = CGFloat(idx / 36) / 5.0
                let g = CGFloat((idx / 6) % 6) / 5.0
                let b = CGFloat(idx % 6) / 5.0
                return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
            } else {
                // Grayscale: 232-255 → 8, 18, ..., 238
                let gray = (CGFloat(Int(n) - 232) * 10.0 + 8.0) / 255.0
                return NSColor(white: gray, alpha: 1)
            }
        case .rgb(let r, let g, let b):
            return NSColor(
                srgbRed: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1
            )
        }
    }

    private static func standardNSColor(_ n: UInt8) -> NSColor {
        switch n {
        case 0:  return .black
        case 1:  return NSColor(srgbRed: 0.8, green: 0.0, blue: 0.0, alpha: 1)
        case 2:  return NSColor(srgbRed: 0.0, green: 0.8, blue: 0.0, alpha: 1)
        case 3:  return NSColor(srgbRed: 0.8, green: 0.8, blue: 0.0, alpha: 1)
        case 4:  return NSColor(srgbRed: 0.0, green: 0.0, blue: 0.8, alpha: 1)
        case 5:  return NSColor(srgbRed: 0.8, green: 0.0, blue: 0.8, alpha: 1)
        case 6:  return NSColor(srgbRed: 0.0, green: 0.8, blue: 0.8, alpha: 1)
        case 7:  return .white
        // Bright variants
        case 8:  return .gray
        case 9:  return .systemRed
        case 10: return .systemGreen
        case 11: return .systemYellow
        case 12: return .systemBlue
        case 13: return NSColor(srgbRed: 1.0, green: 0.0, blue: 1.0, alpha: 1)
        case 14: return .systemCyan
        case 15: return NSColor(white: 1.0, alpha: 1)
        default: return .textColor
        }
    }
}

// MARK: - Style → NSAttributedString attributes

extension ANSIStyle {
    var nsAttributes: [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]

        // Font: start with weight, then apply italic if needed
        let size: CGFloat = 13
        var font = NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        if italic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        attrs[.font] = font

        // Foreground color
        attrs[.foregroundColor] = foreground.nsColor ?? NSColor.white

        // Background color
        if let bg = background.nsColor {
            attrs[.backgroundColor] = bg
        }

        // Dim (reduce alpha)
        if dim {
            if let fg = attrs[.foregroundColor] as? NSColor {
                attrs[.foregroundColor] = fg.withAlphaComponent(0.5)
            }
        }

        // Underline
        if underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        // Strikethrough
        if strikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        return attrs
    }
}
