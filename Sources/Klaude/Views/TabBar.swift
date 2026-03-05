import SwiftUI
import KlaudeCore

struct TabBar: View {
    let workspace: Workspace
    let theme: TerminalTheme
    var onAddTab: () -> Void
    var onSave: (() -> Void)?

    @State private var hoveredTabID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var draggingTabID: UUID?

    private let maxTabWidth: CGFloat = 200
    private let minTabWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                let tabCount = max(workspace.tabs.count, 1)
                let addButtonWidth: CGFloat = 32
                let usableWidth = geometry.size.width - addButtonWidth
                let tabWidth = min(maxTabWidth, max(minTabWidth, usableWidth / CGFloat(tabCount)))

                HStack(spacing: 1) {
                    ForEach(workspace.tabs) { tab in
                        tabItem(tab)
                            .frame(width: tabWidth)
                            .opacity(draggingTabID == tab.id ? 0.4 : 1.0)
                            .onDrag {
                                draggingTabID = tab.id
                                return NSItemProvider(object: tab.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: TabDropDelegate(
                                tabID: tab.id,
                                workspace: workspace,
                                draggingTabID: $draggingTabID,
                                onSave: onSave
                            ))
                    }
                }
                .padding(.horizontal, 4)
            }

            // Add tab button
            Button(action: onAddTab) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(theme.sidebarTextSecondary))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .frame(height: 32)
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
        if !trimmed.isEmpty, let target = workspace.tabs.first(where: { $0.id == renameTargetID }) {
            target.name = trimmed
            onSave?()
        }
        renameTargetID = nil
    }

    private func tabStatusDot(_ tab: KlaudeCore.Tab) -> some View {
        StatusDotView(needsAttention: tab.needsAttention, isRunning: tab.isRunning, theme: theme)
    }

    private func tabItem(_ tab: KlaudeCore.Tab) -> some View {
        let isSelected = tab.id == workspace.selectedTabID
        let isHovered = tab.id == hoveredTabID

        return HStack(spacing: 5) {
            tabStatusDot(tab)
                .frame(width: 6, height: 6)

            Text(tab.name)
                .font(.system(size: 12))
                .foregroundStyle(Color(isSelected ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if isHovered && workspace.tabs.count > 1 {
                Button {
                    workspace.removeTab(id: tab.id)
                    onSave?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(theme.sidebarTextSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isSelected
                        ? Color(theme.sidebarSurface)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.4)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredTabID = hovering ? tab.id : nil
        }
        .onTapGesture {
            // Using onTapGesture intentionally: the row needs hover tracking
            // and context menu, which don't compose well with Button styling.
            workspace.selectTab(id: tab.id)
        }
        .contextMenu {
            Button("Rename Tab") {
                editingName = tab.name
                renameTargetID = tab.id
            }
        }
    }
}

private struct TabDropDelegate: DropDelegate {
    let tabID: UUID
    let workspace: Workspace
    @Binding var draggingTabID: UUID?
    var onSave: (() -> Void)?

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingTabID, dragging != tabID else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            workspace.moveTab(fromID: dragging, toID: tabID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabID = nil
        onSave?()
        return true
    }

    func dropExited(info: DropInfo) {
        // No action needed
    }
}

