import Foundation

public enum ViewMode {
    case terminal
    case kanban
}

@Observable
public final class AppModel {
    public let themeManager = ThemeManager()
    public let kanbanStore = KanbanStore()
    public var viewMode: ViewMode = .terminal
    public var workspaces: [Workspace] = []
    public var selectedWorkspaceID: UUID?
    public var sidebarVisible: Bool = true
    private var workspaceCounter = 0

    public var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    public init() {
        let workspace = addWorkspace()
        selectedWorkspaceID = workspace.id
    }

    @discardableResult
    public func addWorkspace() -> Workspace {
        workspaceCounter += 1
        let workspace = Workspace(name: "Workspace \(workspaceCounter)")
        workspaces.append(workspace)
        return workspace
    }

    public func removeWorkspace(at offsets: IndexSet) {
        for index in offsets.reversed() {
            workspaces.remove(at: index)
        }
    }

    public func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
    }

    public func toggleSidebar() {
        sidebarVisible.toggle()
    }
}
