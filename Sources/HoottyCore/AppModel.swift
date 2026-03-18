import Foundation

@MainActor
@Observable
public final class AppModel {
    public let configFile: ConfigFile
    public let themeManager: ThemeManager
    public let soundManager: SoundManager
    public let workspaceStore: WorkspaceStore
    public let pipelineModel: PipelineModel
    public let macroStore: MacroStore
    public let macroRunner: MacroRunner
    public var workspaces: [Workspace] = []
    public var selectedWorkspaceID: UUID?
    public var sidebarVisible: Bool = true
    public var sidebarWidth: CGFloat = 260

    public enum ModalState {
        case none
        case commandPalette
        case themePicker
    }

    public enum DetailMode {
        case terminals
        case board
    }

    public enum AppMode {
        case workspaces
        case pipelines
    }

    public enum PipelineMode {
        case boards
        case templates
    }

    public var modalState: ModalState = .none
    public var detailMode: DetailMode = .terminals
    public var appMode: AppMode = .workspaces
    public var pipelineMode: PipelineMode = .boards
    public var sidebarHasFocus: Bool = false
    public private(set) var paneEventHandler: PaneEventHandler!

    public static let sidebarMinWidth: CGFloat = 140
    public static let sidebarMaxWidth: CGFloat = 400
    public var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    public init(workspaceStore: WorkspaceStore = WorkspaceStore(), configFile: ConfigFile? = nil, themesDirectory: URL? = nil, pipelineModel: PipelineModel? = nil, macroStore: MacroStore? = nil, macroRunner: MacroRunner? = nil) {
        let resolvedConfigFile = configFile ?? ConfigFile()
        self.configFile = resolvedConfigFile
        resolvedConfigFile.ensureExists()
        let catalog = ThemeCatalog(themesDirectory: themesDirectory)
        self.themeManager = ThemeManager(configFile: resolvedConfigFile, themeCatalog: catalog)
        self.soundManager = SoundManager(configFile: resolvedConfigFile)
        self.workspaceStore = workspaceStore
        self.pipelineModel = pipelineModel ?? PipelineModel()
        self.macroStore = macroStore ?? MacroStore()
        self.macroRunner = macroRunner ?? MacroRunner()
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
        while existingNumbers.contains(n) {
            n += 1
        }
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

    /// Collect panes in a repo root with their session IDs for pipeline matching.
    public func pipelinePanes(forRepoRoot repoRoot: String) -> [(id: UUID, sessionIDs: [String])] {
        var result: [(id: UUID, sessionIDs: [String])] = []
        for workspace in workspaces {
            for pane in workspace.allPanes where pane.repoRoot == repoRoot {
                var ids = [pane.id.uuidString]
                if let sid = pane.claudeSessionID, sid != "auto" {
                    ids.append(sid)
                }
                result.append((id: pane.id, sessionIDs: ids))
            }
        }
        return result
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
        macroRunner.removeAll()
        workspaceStore.deleteStorage()
        workspaces = []
        sidebarWidth = 260
        sidebarVisible = true
        let workspace = addWorkspace()
        selectedWorkspaceID = workspace.id
    }

    public var showWorktreeActions: Bool {
        get { configFile.defaultTrueBool("hootty-show-worktree-actions") }
        set { configFile.setDefaultTrueBool("hootty-show-worktree-actions", newValue) }
    }

    public var pipelinesEnabled: Bool {
        get { configFile.defaultFalseBool("hootty-module-pipelines") }
        set { configFile.setDefaultFalseBool("hootty-module-pipelines", newValue) }
    }

    public var macrosEnabled: Bool {
        get { configFile.defaultFalseBool("hootty-module-macros") }
        set { configFile.setDefaultFalseBool("hootty-module-macros", newValue) }
    }

    public var moduleFlags: ModuleFlags {
        ModuleFlags(pipelines: pipelinesEnabled, macros: macrosEnabled)
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

    /// Refresh pipeline state for all panes in a specific repo root.
    public func refreshPipeline(repoRoot: String) {
        let panes = pipelinePanes(forRepoRoot: repoRoot)
        pipelineModel.refresh(repoRoot: repoRoot, panes: panes)
    }

    /// Run `hootty pipeline archive` for a pipeline in the background.
    public func archivePipeline(name: String, repoRoot: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["hootty", "pipeline", "archive", name]
            process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
            try? process.run()
            process.waitUntilExit()
            DispatchQueue.main.async { [weak self] in
                self?.refreshPipeline(repoRoot: repoRoot)
            }
        }
    }
}
