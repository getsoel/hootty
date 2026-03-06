import SwiftUI
import HoottyCore

struct PaneGroupView: View {
    @Bindable var group: PaneGroup
    let isFocused: Bool
    let theme: TerminalTheme
    let onFocusPaneGroup: (UUID) -> Void
    let onAddPane: () -> Void
    let onRemovePane: (UUID) -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaneGroupTabBar(
                group: group,
                isFocused: isFocused,
                theme: theme,
                onAddPane: onAddPane,
                onRemovePane: onRemovePane,
                onSave: onSave
            )

            ZStack {
                ForEach(group.panes) { pane in
                    TerminalPaneView(pane: pane, isFocused: isFocused && pane.id == group.selectedPaneID)
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
