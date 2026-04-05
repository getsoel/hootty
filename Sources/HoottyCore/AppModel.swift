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

    // MARK: - Persistent Panel

    public var persistentNode: SplitNode?
    public var persistentPanelVisible: Bool = false
    public var persistentPanelWidth: CGFloat = 400
    public var persistentFocusedPaneID: UUID?
    public var persistentSidebarCollapsed: Bool = false
    public var focusDomain: FocusDomain = .workspace

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
    public static let persistentPanelMinWidth: CGFloat = 200
    public static let persistentPanelMaxWidth: CGFloat = 600
    public nonisolated static let persistentWorkspaceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    public var persistentFocusedPane: Pane? {
        guard let node = persistentNode else { return nil }
        if let id = persistentFocusedPaneID, let pane = node.findPane(id: id) {
            return pane
        }
        return node.firstPane()
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
            if let node = snapshot.persistentNode {
                self.persistentNode = node
                self.persistentFocusedPaneID = node.firstPane()?.id
            }
            if let visible = snapshot.persistentPanelVisible {
                self.persistentPanelVisible = visible
            }
            if let width = snapshot.persistentPanelWidth {
                self.persistentPanelWidth = width
            }
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
            persistentNode: persistentNode,
            persistentPanelVisible: persistentPanelVisible ? true : nil,
            persistentPanelWidth: persistentPanelWidth != 400 ? persistentPanelWidth : nil
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
            collapsedWorkspaceIDs.remove(workspaces[index].id)
            workspaces.remove(at: index)
        }
        saveWorkspaces()
    }

    public func removeWorkspace(id: UUID) {
        collapsedWorkspaceIDs.remove(id)
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

    /// Find a pane by ID across both workspaces and the persistent panel.
    public enum PaneLocation {
        case workspace(Workspace, Pane)
        case persistent(Pane)
    }

    public func findPaneLocation(id: UUID) -> PaneLocation? {
        if let (workspace, pane) = findPane(id: id) {
            return .workspace(workspace, pane)
        }
        if let pane = persistentNode?.findPane(id: id) {
            return .persistent(pane)
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
        persistentNode = nil
        persistentPanelVisible = false
        persistentPanelWidth = 400
        persistentFocusedPaneID = nil
        focusDomain = .workspace
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

    // MARK: - Persistent Panel

    public func togglePersistentPanel() {
        if persistentPanelVisible {
            persistentPanelVisible = false
        } else {
            if persistentNode == nil {
                let pane = Pane(name: "Pinned 1")
                persistentNode = SplitNode(pane: pane)
                persistentFocusedPaneID = pane.id
            }
            persistentPanelVisible = true
        }
        saveWorkspaces()
    }

    public func closePersistentPanel() {
        persistentNode = nil
        persistentPanelVisible = false
        persistentFocusedPaneID = nil
        if focusDomain == .persistent {
            focusDomain = .workspace
        }
        saveWorkspaces()
    }

    /// Remove a pane from the persistent panel. Closes the panel if it was the last pane.
    public func removePersistentPane(id: UUID) {
        guard let node = persistentNode else { return }
        if !node.removePane(id: id) {
            closePersistentPanel()
        } else if persistentFocusedPaneID == id {
            persistentFocusedPaneID = node.firstPane()?.id
        }
        saveWorkspaces()
    }

    /// Split the focused persistent pane. Returns the new pane if successful.
    @discardableResult
    public func splitPersistentPane(direction: SplitDirection, placeBefore: Bool = false) -> Pane? {
        guard let node = persistentNode,
              let focused = persistentFocusedPane else { return nil }
        let newPane = Pane(name: "Pinned \(node.allPanes().count + 1)")
        guard node.splitPane(paneID: focused.id, direction: direction, newPane: newPane, placeBefore: placeBefore) else { return nil }
        persistentFocusedPaneID = newPane.id
        saveWorkspaces()
        return newPane
    }

    /// Add a new pane to the persistent panel (appended as a vertical split).
    @discardableResult
    public func addPersistentPane() -> Pane? {
        guard let node = persistentNode,
              let lastPane = node.allPanes().last else { return nil }
        let newPane = Pane(name: "Pinned \(node.allPanes().count + 1)")
        guard node.splitPane(paneID: lastPane.id, direction: .vertical, newPane: newPane) else { return nil }
        persistentFocusedPaneID = newPane.id
        saveWorkspaces()
        return newPane
    }

    /// All panes in the persistent panel (empty if no panel).
    public var persistentPanes: [Pane] {
        persistentNode?.allPanes() ?? []
    }

    /// Cycle focus within the persistent panel (next/previous).
    public func cyclePersistentFocus(forward: Bool) {
        let panes = persistentPanes
        guard panes.count > 1, let currentID = persistentFocusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIdx = forward ? (idx + 1) % panes.count : (idx - 1 + panes.count) % panes.count
        persistentFocusedPaneID = panes[nextIdx].id
    }

    /// Cross-domain directional focus that considers both workspace and persistent panel panes.
    public func focusPaneInDirection(_ direction: FocusDirection) {
        let currentID: UUID? = if focusDomain == .persistent {
            persistentFocusedPaneID
        } else {
            selectedWorkspace?.focusedPaneID
        }
        guard let currentID else { return }

        guard persistentPanelVisible, let persistentNode else {
            selectedWorkspace?.focusPaneInDirection(direction)
            return
        }

        // Map both domain rects into a shared coordinate space (approximate; actual
        // window geometry isn't available in the model layer, but the ratio only
        // affects edge-case tie-breaking between candidates).
        let panelFraction = persistentPanelWidth / (persistentPanelWidth + 800)
        let workspaceFraction = 1.0 - panelFraction

        var combinedRects: [UUID: CGRect] = [:]
        if let workspace = selectedWorkspace {
            for (id, rect) in workspace.rootNode.paneRects() {
                combinedRects[id] = CGRect(
                    x: rect.origin.x * workspaceFraction,
                    y: rect.origin.y,
                    width: rect.width * workspaceFraction,
                    height: rect.height
                )
            }
        }
        for (id, rect) in persistentNode.paneRects() {
            combinedRects[id] = CGRect(
                x: workspaceFraction + rect.origin.x * panelFraction,
                y: rect.origin.y,
                width: rect.width * panelFraction,
                height: rect.height
            )
        }

        guard let bestID = FocusDirection.nearestPane(from: currentID, in: combinedRects, direction: direction) else { return }

        if persistentNode.containsPane(id: bestID) {
            focusDomain = .persistent
            persistentFocusedPaneID = bestID
        } else if let workspace = selectedWorkspace {
            focusDomain = .workspace
            workspace.focusPane(id: bestID)
        }
    }

    /// Move a pane from a workspace into the persistent panel.
    public func movePaneToPersistentPanel(paneID: UUID) {
        guard let (workspace, pane) = findPane(id: paneID) else { return }

        let wasOnlyPane = workspace.allPanes.count == 1
        if !wasOnlyPane {
            workspace.rootNode.removePane(id: paneID)
            if workspace.focusedPaneID == paneID {
                workspace.focusedPaneID = workspace.rootNode.firstPane()?.id
            }
        } else {
            let replacement = Pane(name: "Pane 1")
            workspace.rootNode = SplitNode(pane: replacement)
            workspace.focusedPaneID = replacement.id
        }

        if let node = persistentNode, let lastPane = node.allPanes().last {
            node.splitPane(paneID: lastPane.id, direction: .vertical, newPane: pane)
        } else {
            persistentNode = SplitNode(pane: pane)
        }
        persistentFocusedPaneID = pane.id
        persistentPanelVisible = true
        focusDomain = .persistent
        saveWorkspaces()
    }

    /// Move a pane from the persistent panel into a workspace.
    public func movePaneToWorkspace(paneID: UUID, workspaceID: UUID) {
        guard let node = persistentNode,
              let pane = node.findPane(id: paneID),
              let workspace = workspaces.first(where: { $0.id == workspaceID }) else { return }

        // Remove from persistent panel
        let wasOnlyPane = node.allPanes().count == 1
        if !wasOnlyPane {
            node.removePane(id: paneID)
            if persistentFocusedPaneID == paneID {
                persistentFocusedPaneID = node.firstPane()?.id
            }
        } else {
            persistentNode = nil
            persistentPanelVisible = false
            persistentFocusedPaneID = nil
        }

        // Add to workspace
        if let focused = workspace.focusedPane {
            workspace.rootNode.splitPane(paneID: focused.id, direction: .vertical, newPane: pane)
        }
        workspace.focusedPaneID = pane.id
        focusDomain = .workspace
        saveWorkspaces()
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
