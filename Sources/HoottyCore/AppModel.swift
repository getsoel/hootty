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
    public var sidebarWidth: CGFloat = 260

    public enum ModalState {
        case none
        case commandPalette
        case themePicker
    }
    public var modalState: ModalState = .none
    public var sidebarHasFocus: Bool = false

    public static let sidebarMinWidth: CGFloat = 140
    public static let sidebarMaxWidth: CGFloat = 400
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
        let workspace = Workspace(name: nextWorkspaceName())
        workspaces.append(workspace)
        saveWorkspaces()
        return workspace
    }

    private func nextWorkspaceName() -> String {
        let existingNumbers: Set<Int> = Set(workspaces.compactMap { workspace in
            let prefix = "Workspace "
            guard workspace.name.hasPrefix(prefix),
                  let num = Int(workspace.name.dropFirst(prefix.count)) else { return nil }
            return num
        })
        var n = 1
        while existingNumbers.contains(n) { n += 1 }
        return "Workspace \(n)"
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
        withPane(id: paneID) { workspace, pane in
            let isFocusedPane = workspace.id == selectedWorkspaceID
                && workspace.focusedPaneID == paneID
            if !isFocusedPane {
                pane.attentionKind = kind
                return true
            }
            return false
        } ?? false
    }

    @discardableResult
    public func handleBell(_ paneID: UUID) -> Bool {
        withPane(id: paneID) { _, pane in
            pane.attentionKind = .bell
            return true
        } ?? false
    }

    public func handlePaneThinkingChanged(_ paneID: UUID, isThinking: Bool) {
        withPane(id: paneID) { _, pane in
            pane.isThinking = isThinking
            if isThinking {
                pane.attentionKind = nil
            }
        }
    }

    public func handleTitleChange(_ paneID: UUID, title: String) {
        withPane(id: paneID) { _, pane in
            guard pane.claudeSessionID != nil else { return }
            guard let state = ClaudeTitleParser.parse(title) else { return }

            switch state {
            case .thinking:
                if !pane.isThinking {
                    pane.isThinking = true
                    pane.attentionKind = nil
                }
            case .idle:
                if pane.isThinking { pane.isThinking = false }
            }
        }
    }

    public func handlePwdChanged(_ paneID: UUID, pwd: String) {
        withPane(id: paneID) { workspace, pane in
            let newBranch = GitWorktreeManager.currentBranch(for: pwd)

            // Short-circuit: non-git directory and pane already has no branch — skip extra subprocess calls
            if newBranch == nil && pane.branch == nil {
                return
            }

            let canonicalRoot = GitWorktreeManager.canonicalRepoRoot(for: pwd)
            let showToplevel = GitWorktreeManager.repoRoot(for: pwd)
            let newWorktreePath = GitWorktreeManager.isWorktree(for: pwd) ? showToplevel : nil
            var changed = false
            if pane.branch != newBranch {
                pane.branch = newBranch
                changed = true
            }
            if pane.repoRoot != canonicalRoot {
                pane.repoRoot = canonicalRoot
                changed = true
            }
            if pane.worktreePath != newWorktreePath {
                pane.worktreePath = newWorktreePath
                changed = true
            }
            if newWorktreePath == nil, let root = canonicalRoot, let branch = newBranch,
               workspace.headBranches[root] != branch {
                workspace.headBranches[root] = branch
                changed = true
            }
            if workspace.repoPath == nil, let root = canonicalRoot {
                workspace.repoPath = root
                changed = true
            }
            if changed { debouncedSave() }
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

    /// Convenience: look up a pane by ID and execute a closure if found.
    @discardableResult
    public func withPane<T>(id: UUID, _ body: (Workspace, Pane) -> T) -> T? {
        guard let (workspace, pane) = findPane(id: id) else { return nil }
        return body(workspace, pane)
    }

    public func resetWorkspaces() {
        workspaceStore.deleteStorage()
        workspaces = []
        sidebarWidth = 260
        sidebarVisible = true
        let workspace = addWorkspace()
        selectedWorkspaceID = workspace.id
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
