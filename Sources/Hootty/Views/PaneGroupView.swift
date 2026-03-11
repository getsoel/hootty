import SwiftUI
import UniformTypeIdentifiers
import HoottyCore

struct PaneContentView: View {
    var pane: Pane
    let isFocused: Bool
    let tokens: DesignTokens
    let onFocusPane: () -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onClosePane: ((UUID) -> Void)?
    var onSwapPanes: ((UUID, UUID) -> Void)?
    let onSave: () -> Void

    @State private var isDropTarget = false

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

            TerminalPaneView(pane: pane, isFocused: isFocused, onFocusPane: onFocusPane)
        }
        .overlay {
            if !isFocused {
                Color(tokens.unfocusedDimColor)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if let kind = pane.attentionKind {
                Color.clear
                    .glowBorder(
                        shape: Rectangle(),
                        color: Color(tokens.attentionColor(for: kind)),
                        lineWidth: 2,
                        glowRadius: kind == .input ? 8 : 6
                    )
            } else if isFocused {
                Rectangle()
                    .stroke(Color(tokens.borderFocused), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if isDropTarget {
                Rectangle()
                    .stroke(Color(tokens.textAccent), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusPane()
        }
        .onDrop(of: [.utf8PlainText], delegate: PaneSwapDropDelegate(
            targetPaneID: pane.id,
            isDropTarget: $isDropTarget,
            onSwapPanes: onSwapPanes
        ))
    }
}

private struct PaneSwapDropDelegate: DropDelegate {
    let targetPaneID: UUID
    @Binding var isDropTarget: Bool
    let onSwapPanes: ((UUID, UUID) -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.utf8PlainText])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if !isDropTarget { isDropTarget = true }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        isDropTarget = false
        guard let item = info.itemProviders(for: [.utf8PlainText]).first else { return false }
        item.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let str = String(data: data, encoding: .utf8),
                  let sourceID = UUID(uuidString: str) else { return }
            DispatchQueue.main.async {
                onSwapPanes?(sourceID, targetPaneID)
            }
        }
        return true
    }

    func dropExited(info: DropInfo) {
        isDropTarget = false
    }
}
