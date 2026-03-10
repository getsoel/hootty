import Foundation

@Observable
public final class AppModel {
    public let configFile: ConfigFile
    public let themeManager: ThemeManager
    public let soundManager: SoundManager
    public let workspaceStore: WorkspaceStore
    public var workspaces: [Workspace] = []
    public var selectedWorkspaceID: UUID?
    public var sidebarVisible: Bool = true
    public var sidebarWidth: CGFloat = 200

    public enum ModalState {
        case none
        case commandPalette
        case themePicker
    }
    public var modalState: ModalState = .none

    public static let sidebarMinWidth: CGFloat = 140
    public static let sidebarMaxWidth: CGFloat = 400
    private var workspaceCounter = 0

    public var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    public init(workspaceStore: WorkspaceStore = WorkspaceStore(), configFile: ConfigFile = ConfigFile(), themesDirectory: URL? = nil) {
        self.configFile = configFile
        configFile.ensureExists()
        let catalog = ThemeCatalog(themesDirectory: themesDirectory)
        self.themeManager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        self.soundManager = SoundManager(configFile: configFile)
        self.workspaceStore = workspaceStore
        if let snapshot = workspaceStore.load() {
            self.workspaces = snapshot.workspaces
            self.selectedWorkspaceID = snapshot.selectedWorkspaceID
            self.workspaceCounter = snapshot.workspaces.count
            if let width = snapshot.sidebarWidth {
                self.sidebarWidth = width
            }
            if let visible = snapshot.sidebarVisible {
                self.sidebarVisible = visible
            }
        } else {
            let workspace = addWorkspace()
            selectedWorkspaceID = workspace.id
        }
    }

    private var saveDebounceTask: DispatchWorkItem?

    public func saveWorkspaces() {
        let snapshot = WorkspaceSnapshot(
            workspaces: workspaces,
            selectedWorkspaceID: selectedWorkspaceID,
            sidebarWidth: sidebarWidth,
            sidebarVisible: sidebarVisible
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

    public func moveWorkspace(id: UUID, toIndex: Int) {
        guard let fromIndex = workspaces.firstIndex(where: { $0.id == id }),
              fromIndex != toIndex,
              toIndex >= 0, toIndex <= workspaces.count else { return }
        let workspace = workspaces.remove(at: fromIndex)
        let insertIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
        workspaces.insert(workspace, at: insertIndex)
        saveWorkspaces()
    }

    @discardableResult
    public func handlePaneNeedsAttention(_ paneID: UUID, kind: AttentionKind) -> Bool {
        for workspace in workspaces {
            guard let pane = workspace.findPane(id: paneID) else { continue }
            let isFocusedPane = workspace.id == selectedWorkspaceID
                && workspace.focusedPaneID == paneID
            if !isFocusedPane {
                pane.attentionKind = kind
                return true
            }
            return false
        }
        return false
    }

    @discardableResult
    public func handleBell(_ paneID: UUID) -> Bool {
        for workspace in workspaces {
            guard let pane = workspace.findPane(id: paneID) else { continue }
            let isFocusedPane = workspace.id == selectedWorkspaceID
                && workspace.focusedPaneID == paneID
            if isFocusedPane {
                pane.attentionKind = .bell
            } else {
                pane.attentionKind = .input
            }
            return true
        }
        return false
    }

    public func handlePaneThinkingChanged(_ paneID: UUID, isThinking: Bool) {
        for workspace in workspaces {
            guard let pane = workspace.findPane(id: paneID) else { continue }
            pane.isThinking = isThinking
            if isThinking {
                pane.attentionKind = nil
            }
            break
        }
    }

    public func findPane(id: UUID) -> (Workspace, Pane)? {
        for workspace in workspaces {
            if let pane = workspace.findPane(id: id) {
                return (workspace, pane)
            }
        }
        return nil
    }

    public func toggleSidebar() {
        sidebarVisible.toggle()
        saveWorkspaces()
    }

    public func selectNextWorkspace() {
        guard workspaces.count > 1,
              let current = selectedWorkspaceID,
              let idx = workspaces.firstIndex(where: { $0.id == current }) else { return }
        let nextIdx = (idx + 1) % workspaces.count
        selectedWorkspaceID = workspaces[nextIdx].id
    }

    public func selectPreviousWorkspace() {
        guard workspaces.count > 1,
              let current = selectedWorkspaceID,
              let idx = workspaces.firstIndex(where: { $0.id == current }) else { return }
        let prevIdx = (idx - 1 + workspaces.count) % workspaces.count
        selectedWorkspaceID = workspaces[prevIdx].id
    }
}
