import Foundation

@MainActor
@Observable
public final class AppModel {
    public private(set) var configFile: ConfigFile
    public let themeManager: ThemeManager
    public let soundManager: SoundManager
    public private(set) var workspaceStore: WorkspaceStore
    public let profileStore: ProfileStore
    public var profiles: [Profile] = []
    public var activeProfileID = UUID()
    public var workspaces: [Workspace] = []
    public var selectedWorkspaceID: UUID?
    public var sidebarMode: SidebarMode = .full
    public var sidebarWidth: CGFloat = 260
    public var collapsedWorkspaceIDs: Set<UUID> = []
    public var activeSidebarFilters: Set<SidebarFilter> = []
    public var pinnedWorkspaceID: UUID?

    public var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID }
    }

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

    public init(
        profileStore: ProfileStore? = nil,
        workspaceStore: WorkspaceStore? = nil,
        configFile: ConfigFile? = nil,
        themesDirectory: URL? = nil
    ) {
        let resolvedProfileStore = profileStore ?? ProfileStore()
        self.profileStore = resolvedProfileStore

        // Run migration and load profile metadata
        resolvedProfileStore.migrateIfNeeded()
        let defaultProfile = Profile(name: "Default")
        let metadata = resolvedProfileStore.loadMetadata()
            ?? ProfilesMetadata(activeProfileID: defaultProfile.id, profiles: [defaultProfile])
        self.profiles = metadata.profiles
        self.activeProfileID = metadata.activeProfileID

        // Resolve per-profile stores (test overrides take precedence)
        let resolvedWorkspaceStore = workspaceStore ?? resolvedProfileStore.workspaceStore(for: metadata.activeProfileID)
        let resolvedConfigFile = configFile ?? resolvedProfileStore.configFile(for: metadata.activeProfileID)

        self.configFile = resolvedConfigFile
        resolvedConfigFile.ensureExists()
        let catalog = ThemeCatalog(themesDirectory: themesDirectory)
        self.themeManager = ThemeManager(configFile: resolvedConfigFile, themeCatalog: catalog)
        self.soundManager = SoundManager(configFile: resolvedConfigFile)
        self.workspaceStore = resolvedWorkspaceStore
        if let snapshot = resolvedWorkspaceStore.load() {
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
        collapsedWorkspaceIDs.contains(id)
    }

    // MARK: - Sidebar Filters

    public func toggleSidebarFilter(_ filter: SidebarFilter) {
        activeSidebarFilters.formSymmetricDifference([filter])
    }

    public func clearSidebarFilters() {
        activeSidebarFilters.removeAll()
    }

    // MARK: - Profile CRUD

    private func saveProfileMetadata() {
        let metadata = ProfilesMetadata(activeProfileID: activeProfileID, profiles: profiles)
        profileStore.saveMetadata(metadata)
    }

    private func nextProfileName(base: String) -> String {
        let existingNames = Set(profiles.map(\.name))
        if !existingNames.contains(base) { return base }
        var n = 2
        while existingNames.contains("\(base) \(n)") {
            n += 1
        }
        return "\(base) \(n)"
    }

    @discardableResult
    public func createProfile(named name: String) -> Profile {
        let disambiguated = nextProfileName(base: name)
        let profile = Profile(name: disambiguated)
        profileStore.createProfileDirectory(id: profile.id)
        profiles.append(profile)
        saveProfileMetadata()
        return profile
    }

    public func renameProfile(id: UUID, to newName: String) {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = newName
        saveProfileMetadata()
    }

    public func deleteProfile(id: UUID) {
        guard profiles.count > 1 else { return }
        // If deleting the active profile, switch to the first other profile
        if id == activeProfileID {
            if let other = profiles.first(where: { $0.id != id }) {
                switchProfile(to: other.id)
            }
        }
        profiles.removeAll { $0.id == id }
        profileStore.deleteProfileDirectory(id: id)
        saveProfileMetadata()
    }

    // MARK: - Profile Switching

    /// Closure called during profile switch to tear down ghostty surfaces for a workspace.
    /// Set by the UI layer (HoottyApp) since HoottyCore cannot import AppKit/GhosttyApp.
    public var onTeardownWorkspace: ((Workspace) -> Void)?

    /// Closure called during profile switch to reload ghostty config.
    /// Set by the UI layer (HoottyApp).
    public var onReloadConfig: ((String) -> Void)?

    /// Called once after all workspace surfaces are torn down, before state swap.
    /// Used by the UI layer to verify teardown completeness (task 6.9).
    public var onAfterTeardown: (() -> Void)?

    public func switchProfile(to targetID: UUID) {
        guard targetID != activeProfileID else { return }
        guard profiles.contains(where: { $0.id == targetID }) else { return }

        // 1. Flush pending debounced save and persist current state
        saveDebounceTask?.cancel()
        saveDebounceTask = nil
        saveWorkspaces()

        // 2. Tear down surfaces for all current workspaces
        for workspace in workspaces {
            onTeardownWorkspace?(workspace)
        }
        onAfterTeardown?()

        // 3. Swap workspace store and config file to the target profile's instances
        let newWorkspaceStore = profileStore.workspaceStore(for: targetID)
        let newConfigFile = profileStore.configFile(for: targetID)
        newConfigFile.ensureExists()

        workspaceStore = newWorkspaceStore
        configFile = newConfigFile

        // 4. Reload ghostty config with new profile's settings
        onReloadConfig?(newConfigFile.ghosttyConfigContent())

        // 5. Update theme manager to use new config
        themeManager.updateConfigFile(newConfigFile)
        soundManager.updateConfigFile(newConfigFile)

        // 6. Hydrate workspace state from the target profile
        if let snapshot = newWorkspaceStore.load() {
            workspaces = snapshot.workspaces
            selectedWorkspaceID = snapshot.selectedWorkspaceID
            if let width = snapshot.sidebarWidth {
                sidebarWidth = width
            }
            if let mode = snapshot.sidebarMode {
                sidebarMode = mode
            }
            if let collapsed = snapshot.collapsedWorkspaceIDs {
                collapsedWorkspaceIDs = collapsed
            } else {
                collapsedWorkspaceIDs = []
            }
            pinnedWorkspaceID = snapshot.pinnedWorkspaceID
            activeSidebarFilters = []
        } else {
            // Empty profile — start fresh
            workspaces = []
            sidebarMode = .full
            sidebarWidth = 260
            collapsedWorkspaceIDs = []
            pinnedWorkspaceID = nil
            activeSidebarFilters = []
            let workspace = addWorkspace()
            selectedWorkspaceID = workspace.id
        }

        // 7. Update active profile ID
        activeProfileID = targetID

        // 8. Persist metadata
        saveProfileMetadata()
    }
}
