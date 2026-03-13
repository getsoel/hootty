import SwiftUI
import HoottyCore

struct SplitLayoutThumbnail: View {
    let layoutRects: [UUID: CGRect]
    let highlightedPaneID: UUID
    let tokens: DesignTokens

    var body: some View {
        Canvas { context, size in
            for (paneID, rect) in layoutRects {
                let isHighlighted = paneID == highlightedPaneID
                let drawRect = CGRect(
                    x: rect.minX * size.width,
                    y: rect.minY * size.height,
                    width: rect.width * size.width,
                    height: rect.height * size.height
                ).insetBy(dx: 0.5, dy: 0.5)

                if isHighlighted {
                    context.fill(Path(drawRect), with: .color(Color(tokens.textMuted).opacity(0.2)))
                    context.stroke(
                        Path(drawRect),
                        with: .color(Color(tokens.textMuted)),
                        lineWidth: 1
                    )
                } else {
                    context.fill(Path(drawRect), with: .color(Color(tokens.textMuted).opacity(0.1)))
                    context.stroke(
                        Path(drawRect),
                        with: .color(Color(tokens.textMuted).opacity(0.3)),
                        lineWidth: 0.5
                    )
                }
            }
        }
        .frame(width: 24, height: 14)
    }
}
