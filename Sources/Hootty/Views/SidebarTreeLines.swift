import HoottyCore
import SwiftUI

/// Column width shared by tree connector gutters and icon frames.
enum TreeLayout {
    static let columnWidth: CGFloat = 16
}

/// Draws vertical tree lines as a background, positioned within the leading padding area.
struct TreeLinesBackground: View {
    let depth: Int
    let tokens: DesignTokens
    var groupColor: NSColor?

    var body: some View {
        Canvas { context, size in
            guard depth > 0 else { return }
            let cw = TreeLayout.columnWidth
            let leadingPad = Spacing.md
            let lineColor = groupColor.map { Color($0).opacity(0.5) }
                ?? Color(tokens.textMuted).opacity(0.3)
            for level in 1 ... depth {
                let x = leadingPad + (CGFloat(level) - 0.5) * cw
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            }
        }
    }
}
