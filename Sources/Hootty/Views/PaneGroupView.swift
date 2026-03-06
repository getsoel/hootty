import SwiftUI
import HoottyCore

struct PaneGroupView: View {
    @Bindable var group: PaneGroup
    let isFocused: Bool
    let tokens: DesignTokens
    let onFocusPaneGroup: (UUID) -> Void
    let onAddPane: () -> Void
    let onRemovePane: (UUID) -> Void
    var onSplitPane: ((SplitDirection) -> Void)?
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaneGroupTabBar(
                group: group,
                isFocused: isFocused,
                tokens: tokens,
                onFocusPaneGroup: { onFocusPaneGroup(group.id) },
                onAddPane: onAddPane,
                onRemovePane: onRemovePane,
                onSplitPane: onSplitPane,
                onSave: onSave
            )

            ZStack {
                ForEach(group.panes) { pane in
                    TerminalPaneView(pane: pane, isFocused: isFocused && pane.id == group.selectedPaneID)
                        .overlay {
                            if pane.needsAttention {
                                Color.clear
                                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.statusWarning), lineWidth: 2)
                            }
                        }
                        .opacity(pane.id == group.selectedPaneID ? 1 : 0)
                        .allowsHitTesting(pane.id == group.selectedPaneID)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusPaneGroup(group.id)
        }
    }
}
