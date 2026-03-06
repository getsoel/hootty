import SwiftUI
import HoottyCore

struct PaneGroupTabBar: View {
    let group: PaneGroup
    let theme: TerminalTheme
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

                HStack(spacing: 1) {
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
                .padding(.horizontal, 4)
            }

            Button(action: onAddPane) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(theme.sidebarTextSecondary))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .frame(height: 28)
        .background(Color(theme.background).opacity(0.8))
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
        StatusDotView(needsAttention: pane.needsAttention, isRunning: pane.isRunning, theme: theme)
    }

    private func paneTab(_ pane: Pane) -> some View {
        let isSelected = pane.id == group.selectedPaneID
        let isHovered = pane.id == hoveredPaneID

        return HStack(spacing: 5) {
            paneStatusDot(pane)
                .frame(width: 5, height: 5)

            Text(pane.displayName)
                .font(.system(size: 11))
                .foregroundStyle(Color(isSelected ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if isHovered {
                Button {
                    onRemovePane(pane.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color(theme.sidebarTextSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isSelected
                        ? Color(theme.sidebarSurface)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.4)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredPaneID = hovering ? pane.id : nil
        }
        .onTapGesture {
            group.selectPane(id: pane.id)
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
