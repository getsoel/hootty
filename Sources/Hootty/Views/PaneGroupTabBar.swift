import SwiftUI
import HoottyCore
import LucideIcons

struct PaneBar: View {
    let pane: Pane
    let isFocused: Bool
    let tokens: DesignTokens
    let onFocusPane: () -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onSave: (() -> Void)?

    private enum HoveredElement: Equatable {
        case split
    }

    @State private var hovered: HoveredElement?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                StatusDotView(attentionKind: pane.attentionKind, isRunning: pane.isRunning, isThinking: pane.isThinking, tokens: tokens)
                    .padding(Spacing.sm)

                Text(pane.displayName)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.textMuted))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, Spacing.sm)

            Spacer(minLength: 0)

            if onSplitPane != nil {
                splitMenu
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .padding(.bottom, -1)
        .background(
            VStack(spacing: 0) {
                Color(tokens.tabBarBackground)
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        )
        .overlay(alignment: .top) {
            if isFocused {
                Rectangle()
                    .fill(Color(tokens.borderFocused))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusPane()
        }
        .contextMenu {
            Button("Rename Pane") {
                editingName = pane.displayName
                renameTargetID = pane.id
            }
        }
        .alert("Rename Pane", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Pane name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
    }

    private var splitMenu: some View {
        Menu {
            Button("Split Right") { onSplitPane?(.horizontal, false) }
            Button("Split Down") { onSplitPane?(.vertical, false) }
            Divider()
            Button("Split Left") { onSplitPane?(.horizontal, true) }
            Button("Split Up") { onSplitPane?(.vertical, true) }
        } label: {
            LucideIcon(Lucide.columns2, size: 12)
                .foregroundStyle(Color(tokens.textMuted))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(hovered == .split ? Color(tokens.elementHover) : Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        hovered = .split
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        if hovered == .split { hovered = nil }
                    @unknown default: break
                    }
                }
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel("Split pane")
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(tokens.border)).frame(width: 1)
        }
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            pane.customName = trimmed
            onSave?()
        }
        renameTargetID = nil
    }
}
