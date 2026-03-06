import SwiftUI
import HoottyCore
import LucideIcons

struct PaneGroupTabBar: View {
    let group: PaneGroup
    let isFocused: Bool
    let tokens: DesignTokens
    var onFocusPaneGroup: () -> Void
    var onAddPane: () -> Void
    var onRemovePane: (UUID) -> Void
    var onSave: (() -> Void)?

    @State private var hoveredPaneID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var draggingPaneID: UUID?

    private let maxTabWidth: CGFloat = 200
    private let minTabWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                let tabCount = max(group.panes.count, 1)
                let addButtonWidth: CGFloat = 28
                let usableWidth = geometry.size.width - addButtonWidth
                let tabWidth = min(maxTabWidth, max(minTabWidth, usableWidth / CGFloat(tabCount)))

                HStack(spacing: 0) {
                    ForEach(group.panes) { pane in
                        paneTab(pane)
                            .frame(width: tabWidth)
                            .opacity(draggingPaneID == pane.id ? 0.4 : 1.0)
                            .onDrag {
                                draggingPaneID = pane.id
                                return NSItemProvider(object: pane.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: PaneTabDropDelegate(
                                paneID: pane.id,
                                group: group,
                                draggingPaneID: $draggingPaneID,
                                onSave: onSave
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            Button(action: onAddPane) {
                LucideIcon(Lucide.plus, size: 10)
                    .foregroundStyle(Color(tokens.textMuted))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.trailing, Spacing.sm)
        }
        .frame(height: 35)
        .padding(.bottom, -1)
        .background(
            VStack(spacing: 0) {
                Color(tokens.tabBarBackground)
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        )
        .alert("Rename Tab", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Tab name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let target = group.panes.first(where: { $0.id == renameTargetID }) {
            target.customName = trimmed
            onSave?()
        }
        renameTargetID = nil
    }

    private func paneStatusDot(_ pane: Pane) -> some View {
        StatusDotView(needsAttention: pane.needsAttention, isRunning: pane.isRunning, tokens: tokens)
    }

    private func paneTab(_ pane: Pane) -> some View {
        let isSelected = pane.id == group.selectedPaneID
        let isHovered = pane.id == hoveredPaneID

        return HStack(spacing: 5) {
            paneStatusDot(pane)
                .frame(width: 5, height: 5)

            Text(pane.displayName)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if isHovered {
                Button {
                    onRemovePane(pane.id)
                } label: {
                    LucideIcon(Lucide.x, size: 7)
                        .foregroundStyle(Color(tokens.textMuted))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(isSelected ? Color(tokens.tabActive) : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(tokens.border)).frame(width: 1)
        }
        .overlay(alignment: .top) {
            if isSelected && isFocused {
                Rectangle()
                    .fill(Color(tokens.borderFocused))
                    .frame(height: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredPaneID = pane.id
                DispatchQueue.main.async {
                    NSCursor.pointingHand.set()
                }
            case .ended:
                hoveredPaneID = nil
            @unknown default:
                break
            }
        }
        .onTapGesture {
            group.selectPane(id: pane.id)
            onFocusPaneGroup()
        }
        .contextMenu {
            Button("Rename Tab") {
                editingName = pane.displayName
                renameTargetID = pane.id
            }
        }
    }
}

private struct PaneTabDropDelegate: DropDelegate {
    let paneID: UUID
    let group: PaneGroup
    @Binding var draggingPaneID: UUID?
    var onSave: (() -> Void)?

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingPaneID, dragging != paneID else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            group.movePane(fromID: dragging, toID: paneID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingPaneID = nil
        onSave?()
        return true
    }

    func dropExited(info: DropInfo) {}
}
