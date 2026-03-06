import Foundation

public enum ViewMode {
    case terminal
    case kanban
}

@Observable
public final class AppModel {
    public let themeManager = ThemeManager()
    public let kanbanStore = KanbanStore()
    public let workspaceStore: WorkspaceStore
    public var viewMode: ViewMode = .terminal
    public var workspaces: [Workspace] = []
    public var selectedWorkspaceID: UUID?
    public var sidebarVisible: Bool = true
    public var sidebarWidth: CGFloat = 200

    public static let sidebarMinWidth: CGFloat = 140
    public static let sidebarMaxWidth: CGFloat = 400
    private var workspaceCounter = 0

    public var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    public init(workspaceStore: WorkspaceStore = WorkspaceStore()) {
        self.workspaceStore = workspaceStore
        if let snapshot = workspaceStore.load() {
            self.workspaces = snapshot.workspaces
            self.selectedWorkspaceID = snapshot.selectedWorkspaceID
            self.workspaceCounter = snapshot.workspaces.count
        } else {
            let workspace = addWorkspace()
            selectedWorkspaceID = workspace.id
        }
    }

    private var saveDebounceTask: DispatchWorkItem?

    public func saveWorkspaces() {
        let snapshot = WorkspaceSnapshot(
            workspaces: workspaces,
            selectedWorkspaceID: selectedWorkspaceID
        )
        workspaceStore.save(snapshot)
    }

    /// Debounced save — coalesces rapid calls (e.g. pwd changes) to at most one save per second.
    public func debouncedSave() {
        saveDebounceTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.saveWorkspaces()
        }
        saveDebounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }

    @discardableResult
    public func addWorkspace() -> Workspace {
        workspaceCounter += 1
        let workspace = Workspace(name: "Workspace \(workspaceCounter)")
        workspaces.append(workspace)
        saveWorkspaces()
        return workspace
    }

    public func removeWorkspace(at offsets: IndexSet) {
        for index in offsets.reversed() {
            workspaces.remove(at: index)
        }
        saveWorkspaces()
    }

    public func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        saveWorkspaces()
    }

    public func handlePaneNeedsAttention(_ paneID: UUID) {
        for workspace in workspaces {
            guard let (group, pane) = workspace.findPane(id: paneID) else { continue }
            let isActiveGroup = workspace.id == selectedWorkspaceID
                && workspace.focusedPaneGroupID == group.id
                && viewMode == .terminal
            let isFocusedPane = isActiveGroup && group.selectedPaneID == paneID
            if !isFocusedPane {
                pane.needsAttention = true
            }
            break
        }
    }

    public func findPane(id: UUID) -> (Workspace, PaneGroup, Pane)? {
        for workspace in workspaces {
            if let (group, pane) = workspace.findPane(id: id) {
                return (workspace, group, pane)
            }
        }
        return nil
    }

    public func toggleSidebar() {
        sidebarVisible.toggle()
    }
}
