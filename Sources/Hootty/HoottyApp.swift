import HoottyCore
import SwiftUI

@main
struct HoottyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        CrashHandler.install()
        MemoryLogger.install()
        Log.lifecycle.info("Hootty starting...")

        // Wire git debug logging through os.Logger
        GitWorktreeManager.logHandler = { level, message in
            if level == "warning" {
                Log.lifecycle.warning("\(message)")
            } else {
                Log.lifecycle.debug("\(message)")
            }
        }

        // Initialize the ghostty backend FIRST — this copies bundled themes
        // to app support directory before ThemeCatalog reads it
        let ghosttyReady = GhosttyApp.shared.app != nil
        if ghosttyReady {
            Log.lifecycle.info("Ghostty backend initialized")
        } else {
            Log.lifecycle.error("Ghostty backend failed to initialize")
        }

        // Now create AppModel — themes directory is populated
        let model = AppModel(themesDirectory: GhosttyApp.themesDirectoryURL)
        _appModel = State(initialValue: model)

        if ghosttyReady, let resolved = GhosttyApp.shared.initialTheme {
            model.themeManager.setResolvedTheme(resolved)
        }

        // Wire NSSound playback into SoundManager (HoottyCore can't import AppKit)
        model.soundManager.soundPlayer = { name in
            NSSound(named: NSSound.Name(name))?.play()
        }

        // Wire profile switching closures (HoottyCore can't import GhosttyApp)
        model.onTeardownWorkspace = { workspace in
            GhosttyApp.shared.cleanupWorkspace(workspace)
        }
        model.onReloadConfig = { [model] content in
            if let resolved = GhosttyApp.shared.reloadConfig(ghosttyContent: content) {
                model.themeManager.setResolvedTheme(resolved)
            }
        }
        model.onAfterTeardown = {
            GhosttyApp.shared.assertTeardownComplete()
        }

        _commandRegistry = State(initialValue: CommandRegistry())

        let watcher = GitHEADWatcher()
        watcher.setOnChange { [model] repoRoot in
            GitWorktreeManager.invalidateBranchCache(forPathsUnder: repoRoot)
            model.refreshBranchesForRepo(repoRoot)
        }
        _headWatcher = State(initialValue: watcher)

        registerCommands()
    }

    @State private var appModel: AppModel
    @State private var commandRegistry: CommandRegistry
    @State private var headWatcher = GitHEADWatcher()

    private var profileSwitchBinding: Binding<UUID> {
        Binding(
            get: { appModel.activeProfileID },
            set: { [appModel, commandRegistry] newID in
                appModel.switchProfile(to: newID)
                Self.refreshProfileSupplementaryCommands(appModel: appModel, commandRegistry: commandRegistry)
            }
        )
    }

    private var sidebarToggleLabel: String {
        switch appModel.sidebarMode {
        case .full: "Condense Sidebar"
        case .condensed: "Hide Sidebar"
        case .hidden: "Show Sidebar"
        }
    }

    @ViewBuilder
    private var workspaceMenuContents: some View {
        Button(AppCommand.newWorkspace.title) {
            commandRegistry.execute(.newWorkspace)
        }
        .keyboardShortcut("t", modifiers: .command)

        Button(AppCommand.closeWorkspace.title) {
            commandRegistry.execute(.closeWorkspace)
        }
        .disabled(appModel.selectedWorkspace == nil)

        Divider()

        Button(AppCommand.splitRight.title) {
            commandRegistry.execute(.splitRight)
        }
        .keyboardShortcut("d", modifiers: .command)

        Button(AppCommand.splitDown.title) {
            commandRegistry.execute(.splitDown)
        }
        .keyboardShortcut("d", modifiers: [.command, .shift])

        Button(AppCommand.splitLeft.title) {
            commandRegistry.execute(.splitLeft)
        }
        .keyboardShortcut("d", modifiers: [.command, .option])

        Button(AppCommand.splitUp.title) {
            commandRegistry.execute(.splitUp)
        }
        .keyboardShortcut("d", modifiers: [.command, .option, .shift])

        Button(AppCommand.equalizeSplits.title) {
            commandRegistry.execute(.equalizeSplits)
        }
        .keyboardShortcut("=", modifiers: [.control, .shift])

        Divider()

        Button(AppCommand.nextWorkspace.title) {
            commandRegistry.execute(.nextWorkspace)
        }
        .disabled(appModel.workspaces.count < 2)

        Button(AppCommand.previousWorkspace.title) {
            commandRegistry.execute(.previousWorkspace)
        }
        .disabled(appModel.workspaces.count < 2)

        Divider()

        Button(AppCommand.focusPaneUp.title) {
            commandRegistry.execute(.focusPaneUp)
        }
        .keyboardShortcut(.upArrow, modifiers: [.command, .option])

        Button(AppCommand.focusPaneDown.title) {
            commandRegistry.execute(.focusPaneDown)
        }
        .keyboardShortcut(.downArrow, modifiers: [.command, .option])

        Button(AppCommand.focusPaneLeft.title) {
            commandRegistry.execute(.focusPaneLeft)
        }
        .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

        Button(AppCommand.focusPaneRight.title) {
            commandRegistry.execute(.focusPaneRight)
        }
        .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

        Divider()

        Button(AppCommand.notePane.title) {
            commandRegistry.execute(.notePane)
        }
        .keyboardShortcut("f", modifiers: [.control, .shift])

        Button(AppCommand.flagPane.title) {
            commandRegistry.execute(.flagPane)
        }
        .keyboardShortcut("g", modifiers: [.control, .shift])

        Divider()

        Button(AppCommand.pinWorkspace.title) {
            commandRegistry.execute(.pinWorkspace)
        }
        .disabled(appModel.selectedWorkspace == nil)

        Button(AppCommand.refreshTerminal.title) {
            commandRegistry.execute(.refreshTerminal)
        }
    }

    // MARK: - Command Registration

    private func registerCommands() {
        commandRegistry.register(.newWorkspace) { [appModel] in
            let workspace = appModel.addWorkspace()
            appModel.selectedWorkspaceID = workspace.id
        }
        commandRegistry.register(.closeWorkspace) { [appModel, headWatcher] in
            guard let workspace = appModel.selectedWorkspace else { return }
            let id = workspace.id
            let repoRoots = Set(workspace.allPanes.compactMap(\.repoRoot))
            GhosttyApp.shared.cleanupWorkspace(workspace)
            appModel.removeWorkspace(id: id)
            if appModel.selectedWorkspaceID == id {
                appModel.selectedWorkspaceID = appModel.workspaces.first?.id
            }
            for root in repoRoots {
                Self.cleanupHeadWatcher(headWatcher, repoRoot: root, appModel: appModel)
            }
        }
        commandRegistry.register(.splitRight) { [appModel] in
            Self.splitPane(appModel: appModel, direction: .horizontal)
        }
        commandRegistry.register(.splitDown) { [appModel] in
            Self.splitPane(appModel: appModel, direction: .vertical)
        }
        commandRegistry.register(.splitLeft) { [appModel] in
            Self.splitPane(appModel: appModel, direction: .horizontal, placeBefore: true)
        }
        commandRegistry.register(.splitUp) { [appModel] in
            Self.splitPane(appModel: appModel, direction: .vertical, placeBefore: true)
        }
        commandRegistry.register(.nextWorkspace) { [appModel] in
            appModel.selectNextWorkspace()
        }
        commandRegistry.register(.previousWorkspace) { [appModel] in
            appModel.selectPreviousWorkspace()
        }
        commandRegistry.register(.focusNextPane) { [appModel] in
            appModel.selectedWorkspace?.focusNextPane()
        }
        commandRegistry.register(.focusPreviousPane) { [appModel] in
            appModel.selectedWorkspace?.focusPreviousPane()
        }
        commandRegistry.register(.focusPaneUp) { [appModel] in
            appModel.focusPaneInDirection(.up)
        }
        commandRegistry.register(.focusPaneDown) { [appModel] in
            appModel.focusPaneInDirection(.down)
        }
        commandRegistry.register(.focusPaneLeft) { [appModel] in
            appModel.focusPaneInDirection(.left)
        }
        commandRegistry.register(.focusPaneRight) { [appModel] in
            appModel.focusPaneInDirection(.right)
        }
        commandRegistry.register(.equalizeSplits) { [appModel] in
            appModel.selectedWorkspace?.equalizeSplits()
        }
        commandRegistry.register(.notePane) { [appModel] in
            guard let pane = appModel.selectedWorkspace?.focusedPane else { return }
            appModel.modalState = .noteEditor(pane.id)
        }
        commandRegistry.register(.flagPane) { [appModel] in
            appModel.selectedWorkspace?.focusedPane?.toggleFlag()
        }
        commandRegistry.register(.toggleSidebar) { [appModel] in
            appModel.toggleSidebar()
        }
        commandRegistry.register(.focusSidebar) { [appModel] in
            appModel.sidebarHasFocus = true
        }
        commandRegistry.register(.toggleCommandPalette) { [appModel] in
            appModel.modalState = appModel.modalState == .commandPalette ? .none : .commandPalette
        }
        commandRegistry.register(.changeTheme) { [appModel] in
            appModel.modalState = .themePicker
        }
        commandRegistry.register(.refreshTerminal) {
            GhosttyApp.shared.refreshAllSurfaces()
        }
        commandRegistry.register(.attentionSounds) { [appModel] in
            appModel.modalState = .attentionSounds
        }
        commandRegistry.register(.collapseAllWorkspaces) { [appModel] in
            appModel.collapseAllWorkspaces()
        }
        commandRegistry.register(.expandAllWorkspaces) { [appModel] in
            appModel.expandAllWorkspaces()
        }
        commandRegistry.register(.clearSidebarFilters) { [appModel] in
            appModel.clearSidebarFilters()
        }
        commandRegistry.register(.resetWorkspaces) { [appModel, headWatcher] in
            for workspace in appModel.workspaces {
                GhosttyApp.shared.cleanupWorkspace(workspace)
            }
            headWatcher.stopAll()
            appModel.resetWorkspaces()
        }
        commandRegistry.register(.editConfig) { [appModel] in
            appModel.configFile.ensureExists()
            NSWorkspace.shared.open(ConfigFile.defaultFileURL)
        }
        commandRegistry.register(.pinWorkspace) { [appModel] in
            guard let id = appModel.selectedWorkspaceID else { return }
            appModel.togglePinWorkspace(id: id)
        }
        commandRegistry.register(.focusPinnedWorkspace) { [appModel] in
            guard let id = appModel.pinnedWorkspaceID else { return }
            appModel.selectedWorkspaceID = id
        }

        // Profile commands
        commandRegistry.register(.newProfile) { [appModel, commandRegistry] in
            guard let name = NSAlertPrompt.promptForName(
                title: "New Profile",
                prompt: "Enter a name for the new profile:"
            ) else { return }
            let profile = appModel.createProfile(named: name)
            appModel.switchProfile(to: profile.id)
            Self.refreshProfileSupplementaryCommands(appModel: appModel, commandRegistry: commandRegistry)
        }
        commandRegistry.register(.renameCurrentProfile) { [appModel, commandRegistry] in
            guard let profile = appModel.activeProfile else { return }
            guard let newName = NSAlertPrompt.promptForName(
                title: "Rename Profile",
                prompt: "Enter a new name:",
                initialValue: profile.name
            ) else { return }
            appModel.renameProfile(id: profile.id, to: newName)
            Self.refreshProfileSupplementaryCommands(appModel: appModel, commandRegistry: commandRegistry)
        }
        commandRegistry.register(.deleteCurrentProfile) { [appModel, commandRegistry] in
            guard appModel.profiles.count > 1,
                  let profile = appModel.activeProfile else { return }
            guard NSAlertPrompt.confirmDestructive(
                title: "Delete Profile",
                message: "Are you sure you want to delete the profile \"\(profile.name)\"? All workspaces in this profile will be permanently lost.",
                confirmButtonTitle: "Delete"
            ) else { return }
            appModel.deleteProfile(id: profile.id)
            Self.refreshProfileSupplementaryCommands(appModel: appModel, commandRegistry: commandRegistry)
        }

        // Initial supplementary commands for profile switching
        Self.refreshProfileSupplementaryCommands(appModel: appModel, commandRegistry: commandRegistry)

        // Wire the registry into GhosttyApp for action callback routing
        GhosttyApp.shared.commandRegistry = commandRegistry
    }

    // MARK: - Ghostty Event Handling

    private static func handleGhosttyEvent(_ event: GhosttyEvent, appModel: AppModel, headWatcher: GitHEADWatcher) {
        switch event {
        case .newTab:
            let workspace = appModel.addWorkspace()
            appModel.selectedWorkspaceID = workspace.id

        case let .bellRang(paneID):
            let didSet = appModel.handleBell(paneID)
            if didSet { appModel.soundManager.play(.bell) }

        case let .paneNeedsAttention(paneID, kind):
            let didSet = appModel.handlePaneNeedsAttention(paneID, kind: kind)
            if didSet { appModel.soundManager.play(kind) }

        case let .agentSessionDetected(paneID, sessionID):
            if let (_, pane) = appModel.findPane(id: paneID) {
                pane.agentSessionID = sessionID
                appModel.debouncedSave()
            }

        case let .newSplit(paneID, direction, parentSurface):
            if let (workspace, _) = appModel.findPane(id: paneID) {
                workspace.focusPane(id: paneID)
                if let newPane = workspace.splitFocusedPane(direction: direction) {
                    if let parentSurface {
                        GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                    }
                    appModel.saveWorkspaces()
                }
            }

        case let .closeSurface(paneID):
            if let (workspace, pane) = appModel.findPane(id: paneID) {
                let repoRoot = pane.repoRoot
                GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                workspace.removePane(id: paneID)
                appModel.saveWorkspaces()
                if let root = repoRoot {
                    Self.cleanupHeadWatcher(headWatcher, repoRoot: root, appModel: appModel)
                }
            }

        case .closeTab:
            guard let workspace = appModel.selectedWorkspace,
                  let focusedPaneID = workspace.focusedPaneID else { return }
            let repoRoot = workspace.findPane(id: focusedPaneID)?.repoRoot
            GhosttyApp.shared.removeCachedSurfaceView(for: focusedPaneID)
            workspace.removePane(id: focusedPaneID)
            appModel.saveWorkspaces()
            if let root = repoRoot {
                cleanupHeadWatcher(headWatcher, repoRoot: root, appModel: appModel)
            }

        case let .commandFinished(paneID, exitCode):
            if exitCode > 128 {
                Log.lifecycle.info("Command in pane \(paneID) killed by signal \(exitCode - 128)")
            }

        case let .titleChanged(paneID, title):
            appModel.handleTitleChange(paneID, title: title)

        case let .pwdChanged(paneID, path):
            appModel.handlePwdChanged(paneID, pwd: path)
            guard let (_, pane) = appModel.findPane(id: paneID),
                  let repoRoot = pane.repoRoot else { return }
            if !headWatcher.watchedRepoRoots.contains(repoRoot),
               let gitDir = GitWorktreeManager.gitCommonDir(for: path) {
                headWatcher.startWatching(repoRoot: repoRoot, gitCommonDir: gitDir)
            }
        }
    }

    private static func refreshProfileSupplementaryCommands(appModel: AppModel, commandRegistry: CommandRegistry) {
        let activeID = appModel.activeProfileID
        let switchCommands: [PaletteCommand] = appModel.profiles
            .filter { $0.id != activeID }
            .map { profile in
                PaletteCommand(
                    id: "switch-profile-\(profile.id.uuidString)",
                    title: "Switch to Profile: \(profile.name)",
                    shortcut: nil,
                    action: { [weak appModel, weak commandRegistry] in
                        appModel?.switchProfile(to: profile.id)
                        if let appModel, let commandRegistry {
                            refreshProfileSupplementaryCommands(appModel: appModel, commandRegistry: commandRegistry)
                        }
                    }
                )
            }
        commandRegistry.setSupplementaryCommands(switchCommands)
    }

    private static func cleanupHeadWatcher(_ watcher: GitHEADWatcher, repoRoot: String, appModel: AppModel) {
        let hasRemainingPanes = appModel.workspaces.contains { workspace in
            workspace.allPanes.contains { $0.repoRoot == repoRoot }
        }
        if !hasRemainingPanes {
            watcher.stopWatching(repoRoot: repoRoot)
        }
    }

    private static func splitPane(appModel: AppModel, direction: SplitDirection, placeBefore: Bool = false) {
        guard let workspace = appModel.selectedWorkspace else { return }
        let parentSurface = GhosttyApp.shared.focusedSurface
        if let newPane = workspace.splitFocusedPane(direction: direction, placeBefore: placeBefore) {
            if let parentSurface {
                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
            }
            appModel.saveWorkspaces()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                appModel: appModel,
                commandRegistry: commandRegistry,
                onCleanupRepoWatchers: { [headWatcher, appModel] repoRoot in
                    Self.cleanupHeadWatcher(headWatcher, repoRoot: repoRoot, appModel: appModel)
                }
            )
            .frame(minWidth: 700, minHeight: 400)
            .onAppear { [headWatcher] in
                // Bootstrap HEAD watchers for persisted repos
                for workspace in appModel.workspaces {
                    for pane in workspace.allPanes {
                        if let repoRoot = pane.repoRoot,
                           !headWatcher.watchedRepoRoots.contains(repoRoot),
                           let gitDir = GitWorktreeManager.gitCommonDir(for: pane.workingDirectory) {
                            headWatcher.startWatching(repoRoot: repoRoot, gitCommonDir: gitDir)
                        }
                    }
                }

                if GhosttyApp.shared.onEvent == nil {
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.willTerminateNotification,
                        object: nil,
                        queue: .main
                    ) { [appModel] _ in
                        appModel.saveWorkspaces()
                    }
                }

                GhosttyApp.shared.onEvent = { [appModel, headWatcher] event in
                    Self.handleGhosttyEvent(event, appModel: appModel, headWatcher: headWatcher)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(AppCommand.editConfig.title) {
                    commandRegistry.execute(.editConfig)
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button(AppCommand.attentionSounds.title) {
                    commandRegistry.execute(.attentionSounds)
                }
            }
            CommandGroup(after: .sidebar) {
                Button(AppCommand.toggleCommandPalette.title) {
                    commandRegistry.execute(.toggleCommandPalette)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button(sidebarToggleLabel) {
                    commandRegistry.execute(.toggleSidebar)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button(AppCommand.focusSidebar.title) {
                    commandRegistry.execute(.focusSidebar)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button(AppCommand.collapseAllWorkspaces.title) {
                    commandRegistry.execute(.collapseAllWorkspaces)
                }

                Button(AppCommand.expandAllWorkspaces.title) {
                    commandRegistry.execute(.expandAllWorkspaces)
                }

                Button(AppCommand.clearSidebarFilters.title) {
                    commandRegistry.execute(.clearSidebarFilters)
                }

                Divider()

                Button(AppCommand.focusPinnedWorkspace.title) {
                    commandRegistry.execute(.focusPinnedWorkspace)
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
            CommandMenu("Workspace") {
                workspaceMenuContents
            }
            CommandMenu("Profile") {
                Picker("Active", selection: profileSwitchBinding) {
                    ForEach(appModel.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .pickerStyle(.inline)

                Divider()

                Button(AppCommand.newProfile.title) {
                    commandRegistry.execute(.newProfile)
                }

                Button(AppCommand.renameCurrentProfile.title) {
                    commandRegistry.execute(.renameCurrentProfile)
                }

                Button(AppCommand.deleteCurrentProfile.title) {
                    commandRegistry.execute(.deleteCurrentProfile)
                }
                .disabled(appModel.profiles.count <= 1)
            }
        }
    }
}
