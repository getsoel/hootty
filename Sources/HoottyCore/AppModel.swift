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
    public var sidebarVisible: Bool = true
    public var sidebarWidth: CGFloat = 260
    public var collapsedWorkspaceIDs: Set<UUID> = []
    public var activeSidebarFilters: Set<SidebarFilter> = []

    // MARK: - Persistent Panel

    public var persistentNode: SplitNode?
    public var persistentPanelVisible: Bool = false
    public var persistentPanelWidth: CGFloat = 400
    public var persistentFocusedPaneID: UUID?
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
    nonisolated public static let persistentWorkspaceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
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
            if let visible = snapshot.sidebarVisible {
                self.sidebarVisible = visible
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
            sidebarVisible: sidebarVisible,
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

    /// Look up a pane by ID across both workspaces and persistent panel.
    @discardableResult
    public func withAnyPane<T>(id: UUID, _ body: (PaneLocation) -> T) -> T? {
        guard let location = findPaneLocation(id: id) else { return nil }
        return body(location)
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
        sidebarVisible = true
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
        // Determine current focused pane ID and build combined rects
        let currentID: UUID?
        if focusDomain == .persistent {
            currentID = persistentFocusedPaneID
        } else {
            currentID = selectedWorkspace?.focusedPaneID
        }
        guard let currentID else { return }

        // If persistent panel is not visible, delegate to workspace-only focus
        guard persistentPanelVisible, let persistentNode else {
            selectedWorkspace?.focusPaneInDirection(direction)
            return
        }

        // Build combined rects: workspace in left region, persistent in right region
        let totalWidth = 1.0 // Normalize to unit space
        let panelFraction = persistentPanelWidth / (persistentPanelWidth + 800) // Approximate ratio
        let workspaceFraction = totalWidth - panelFraction

        var combinedRects: [UUID: CGRect] = [:]

        // Workspace panes mapped to left region
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

        // Persistent panes mapped to right region
        for (id, rect) in persistentNode.paneRects() {
            combinedRects[id] = CGRect(
                x: workspaceFraction + rect.origin.x * panelFraction,
                y: rect.origin.y,
                width: rect.width * panelFraction,
                height: rect.height
            )
        }

        guard let focusedRect = combinedRects[currentID] else { return }

        // Run adjacency algorithm
        let epsilon = 0.001
        var bestID: UUID?
        var bestPrimary = Double.infinity
        var bestPerp = Double.infinity

        for (candidateID, candidateRect) in combinedRects where candidateID != currentID {
            let adj = Self.adjacency(from: focusedRect, to: candidateRect, direction: direction, epsilon: epsilon)
            guard adj.isAdjacent && adj.hasOverlap else { continue }
            if adj.primaryDist < bestPrimary - epsilon
                || (abs(adj.primaryDist - bestPrimary) < epsilon && adj.perpendicularDist < bestPerp)
            {
                bestPrimary = adj.primaryDist
                bestPerp = adj.perpendicularDist
                bestID = candidateID
            }
        }

        guard let bestID else { return }

        // Determine which domain the best pane belongs to
        if persistentNode.containsPane(id: bestID) {
            focusDomain = .persistent
            persistentFocusedPaneID = bestID
        } else if let workspace = selectedWorkspace {
            focusDomain = .workspace
            workspace.focusPane(id: bestID)
        }
    }

    nonisolated private static func adjacency(
        from src: CGRect, to dst: CGRect, direction: FocusDirection, epsilon: Double
    ) -> (isAdjacent: Bool, primaryDist: Double, hasOverlap: Bool, perpendicularDist: Double) {
        let isAdj: Bool
        let primaryDist: Double
        let hasOverlap: Bool
        let perpDist: Double

        switch direction {
        case .right:
            isAdj = dst.minX >= src.maxX - epsilon
            primaryDist = dst.minX - src.maxX
            hasOverlap = dst.maxY > src.minY + epsilon && dst.minY < src.maxY - epsilon
            perpDist = abs(dst.midY - src.midY)
        case .left:
            isAdj = dst.maxX <= src.minX + epsilon
            primaryDist = src.minX - dst.maxX
            hasOverlap = dst.maxY > src.minY + epsilon && dst.minY < src.maxY - epsilon
            perpDist = abs(dst.midY - src.midY)
        case .down:
            isAdj = dst.minY >= src.maxY - epsilon
            primaryDist = dst.minY - src.maxY
            hasOverlap = dst.maxX > src.minX + epsilon && dst.minX < src.maxX - epsilon
            perpDist = abs(dst.midX - src.midX)
        case .up:
            isAdj = dst.maxY <= src.minY + epsilon
            primaryDist = src.minY - dst.maxY
            hasOverlap = dst.maxX > src.minX + epsilon && dst.minX < src.maxX - epsilon
            perpDist = abs(dst.midX - src.midX)
        }

        return (isAdj, primaryDist, hasOverlap, perpDist)
    }

    /// Move a pane from a workspace into the persistent panel.
    public func movePaneToPersistentPanel(paneID: UUID) {
        guard let (workspace, pane) = findPane(id: paneID) else { return }

        // Remove from workspace (preserving object identity)
        let wasOnlyPane = workspace.allPanes.count == 1
        if !wasOnlyPane {
            workspace.rootNode.removePane(id: paneID)
            if workspace.focusedPaneID == paneID {
                workspace.focusedPaneID = workspace.rootNode.firstPane()?.id
            }
        } else {
            // Last pane — create a replacement before removing
            let replacement = Pane(name: "Pane 1")
            workspace.rootNode = SplitNode(pane: replacement)
            workspace.focusedPaneID = replacement.id
        }

        // Add to persistent panel
        if let node = persistentNode {
            node.splitPane(paneID: node.allPanes().last!.id, direction: .vertical, newPane: pane)
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
