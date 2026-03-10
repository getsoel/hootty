import SwiftUI
import HoottyCore

struct PaneContentView: View {
    var pane: Pane
    let isFocused: Bool
    let tokens: DesignTokens
    let onFocusPane: () -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onClosePane: ((UUID) -> Void)?
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaneBar(
                pane: pane,
                isFocused: isFocused,
                tokens: tokens,
                onFocusPane: onFocusPane,
                onSplitPane: onSplitPane,
                onClosePane: onClosePane,
                onSave: onSave
            )

            TerminalPaneView(pane: pane, isFocused: isFocused)
                .overlay {
                    if let kind = pane.attentionKind {
                        Color.clear
                            .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.attentionColor(for: kind)), lineWidth: 2, solidBase: true)
                    }
                }
                .overlay {
                    if !isFocused {
                        Color(tokens.unfocusedDimColor)
                            .allowsHitTesting(false)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusPane()
        }
    }
}
