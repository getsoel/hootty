import Foundation

@MainActor
@Observable
public final class AppModel {
    public let configFile: ConfigFile
    public let themeManager: ThemeManager
    public let soundManager: SoundManager
    public let workspaceStore: WorkspaceStore
    public var workspaces: [Workspace] = []
    public var selectedWorkspaceID: UUID?
    public var sidebarMode: SidebarMode = .full
    public var sidebarWidth: CGFloat = 260
    public var collapsedWorkspaceIDs: Set<UUID> = []
    public var activeSidebarFilters: Set<SidebarFilter> = []
    public var pinnedWorkspaceID: UUID?

    public enum ModalState: Equatable {
        case none
        case commandPalette
        case themePicker
        case attentionSounds
        case memoryLog
        case noteEditor(UUID)
    }

    public var modalState: ModalState = .none
    public var sidebarHasFocus: Bool = false
    public private(set) var paneEventHandler: PaneEventHandler!

    public static let sidebarMinWidth: CGFloat = 200
    public static let sidebarMaxWidth: CGFloat = 400
    public var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    public init(workspaceStore: WorkspaceStore = WorkspaceStore(), configFile: ConfigFile? = nil, themesDirectory: URL? = nil) {
        let resolvedConfigFile = configFile ?? ConfigFile()
        self.configFile = resolvedConfigFile
        resolvedConfigFile.ensureExists()
        let catalog = ThemeCatalog(themesDirectory: themesDirectory)
        self.themeManager = ThemeManager(configFile: resolvedConfigFile, themeCatalog: catalog)
        self.soundManager = SoundManager(configFile: resolvedConfigFile)
        self.workspaceStore = workspaceStore
        if let snapshot = workspaceStore.load() {
            self.workspaces = snapshot.workspaces
            self.selectedWorkspaceID = snapshot.selectedWorkspaceID
            if let width = snapshot.sidebarWidth {
                self.sidebarWidth = width
            }
            if let mode = snapshot.sidebarMode {
                self.sidebarMode = mode
            } else if let visible = snapshot.sidebarVisible {
                self.sidebarMode = visible ? .full : .hidden
            }
            if let collapsed = snapshot.collapsedWorkspaceIDs {
                self.collapsedWorkspaceIDs = collapsed
            }
            self.pinnedWorkspaceID = snapshot.pinnedWorkspaceID
        } else {
            let workspace = addWorkspace()
            self.selectedWorkspaceID = workspace.id
        }
        self.paneEventHandler = PaneEventHandler(
            findPane: { [weak self] id in self?.findPane(id: id) },
            selectedWorkspaceID: { [weak self] in self?.selectedWorkspaceID },
            debouncedSave: { [weak self] in self?.debouncedSave() }
        )
    }

    private var saveDebounceTask: DispatchWorkItem?

    public func saveWorkspaces() {
        let snapshot = WorkspaceSnapshot(
            workspaces: workspaces,
            selectedWorkspaceID: selectedWorkspaceID,
            sidebarWidth: sidebarWidth,
            sidebarMode: sidebarMode,
            collapsedWorkspaceIDs: collapsedWorkspaceIDs.isEmpty ? nil : collapsedWorkspaceIDs,
            pinnedWorkspaceID: pinnedWorkspaceID
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
        while existingNumbers.contains(n) {
            n += 1
        }
        return "Workspace \(n)"
    }

    public func removeWorkspace(at offsets: IndexSet) {
        for index in offsets.reversed() {
            let id = workspaces[index].id
            collapsedWorkspaceIDs.remove(id)
            if pinnedWorkspaceID == id { pinnedWorkspaceID = nil }
            workspaces.remove(at: index)
        }
        saveWorkspaces()
    }

    public func removeWorkspace(id: UUID) {
        collapsedWorkspaceIDs.remove(id)
        if pinnedWorkspaceID == id { pinnedWorkspaceID = nil }
        workspaces.removeAll { $0.id == id }
        saveWorkspaces()
    }

    public func togglePinWorkspace(id: UUID) {
        pinnedWorkspaceID = pinnedWorkspaceID == id ? nil : id
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
        paneEventHandler.handlePaneNeedsAttention(paneID, kind: kind)
    }

    @discardableResult
    public func handleBell(_ paneID: UUID) -> Bool {
        paneEventHandler.handleBell(paneID)
    }

    public func handlePaneThinkingChanged(_ paneID: UUID, isThinking: Bool) {
        paneEventHandler.handlePaneThinkingChanged(paneID, isThinking: isThinking)
    }

    public func handleTitleChange(_ paneID: UUID, title: String) {
        paneEventHandler.handleTitleChange(paneID, title: title)
    }

    public func handlePwdChanged(_ paneID: UUID, pwd: String) {
        paneEventHandler.handlePwdChanged(paneID, pwd: pwd)
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

    /// Re-query branch for all panes in the given canonical repo root.
    /// Called when `.git/HEAD` changes (branch switch without pwd change).
    public func refreshBranchesForRepo(_ canonicalRepoRoot: String) {
        var changed = false
        for workspace in workspaces {
            for pane in workspace.allPanes where pane.repoRoot == canonicalRepoRoot {
                let newBranch = GitWorktreeManager.currentBranch(for: pane.workingDirectory)
                if pane.branch != newBranch {
                    pane.branch = newBranch
                    changed = true
                }
                // Update headBranches for main checkout panes (not worktrees)
                if pane.worktreePath == nil, let branch = newBranch,
                   workspace.headBranches[canonicalRepoRoot] != branch {
                    workspace.headBranches[canonicalRepoRoot] = branch
                    changed = true
                }
            }
        }
        if changed { debouncedSave() }
    }

    public func resetWorkspaces() {
        workspaceStore.deleteStorage()
        workspaces = []
        sidebarWidth = 260
        sidebarMode = .full
        let workspace = addWorkspace()
        selectedWorkspaceID = workspace.id
    }

    public var showLayoutThumbnails: Bool {
        get { configFile.defaultTrueBool("hootty-show-layout-thumbnails") }
        set { configFile.setDefaultTrueBool("hootty-show-layout-thumbnails", newValue) }
    }

    public func toggleSidebar() {
        switch sidebarMode {
        case .full: sidebarMode = .condensed
        case .condensed, .hidden: sidebarMode = .full
        }
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

    /// Directional focus within the selected workspace.
    public func focusPaneInDirection(_ direction: FocusDirection) {
        selectedWorkspace?.focusPaneInDirection(direction)
    }

    // MARK: - Workspace Collapse

    public func toggleWorkspaceCollapse(_ id: UUID) {
        if collapsedWorkspaceIDs.contains(id) {
            collapsedWorkspaceIDs.remove(id)
        } else {
            collapsedWorkspaceIDs.insert(id)
        }
        saveWorkspaces()
    }

    public func collapseAllWorkspaces() {
        collapsedWorkspaceIDs = Set(workspaces.map(\.id))
        saveWorkspaces()
    }

    public func expandAllWorkspaces() {
        collapsedWorkspaceIDs.removeAll()
        saveWorkspaces()
    }

    public func isWorkspaceEffectivelyCollapsed(_ id: UUID) -> Bool {
        collapsedWorkspaceIDs.contains(id) && id != selectedWorkspaceID
    }

    // MARK: - Sidebar Filters

    public func toggleSidebarFilter(_ filter: SidebarFilter) {
        activeSidebarFilters.formSymmetricDifference([filter])
    }

    public func clearSidebarFilters() {
        activeSidebarFilters.removeAll()
    }
}
