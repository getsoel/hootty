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

    private var sidebarToggleLabel: String {
        switch appModel.sidebarMode {
        case .full: "Condense Sidebar"
        case .condensed: "Hide Sidebar"
        case .hidden: "Show Sidebar"
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
            if appModel.focusDomain == .persistent {
                appModel.cyclePersistentFocus(forward: true)
            } else {
                appModel.selectedWorkspace?.focusNextPane()
            }
        }
        commandRegistry.register(.focusPreviousPane) { [appModel] in
            if appModel.focusDomain == .persistent {
                appModel.cyclePersistentFocus(forward: false)
            } else {
                appModel.selectedWorkspace?.focusPreviousPane()
            }
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
        commandRegistry.register(.refreshBranches) {
            // Branch list is now computed on-demand when the picker opens
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
        commandRegistry.register(.toggleDockedPanel) { [appModel] in
            appModel.togglePersistentPanel()
        }
        commandRegistry.register(.focusDockedPanel) { [appModel] in
            appModel.sidebarHasFocus = false
            if appModel.focusDomain == .persistent {
                appModel.focusDomain = .workspace
            } else {
                if !appModel.persistentPanelVisible {
                    appModel.togglePersistentPanel()
                }
                appModel.focusDomain = .persistent
            }
        }
        commandRegistry.register(.movePaneToDockedPanel) { [appModel] in
            guard appModel.focusDomain == .workspace,
                  let workspace = appModel.selectedWorkspace,
                  let pane = workspace.focusedPane else { return }
            appModel.movePaneToPersistentPanel(paneID: pane.id)
        }
        commandRegistry.register(.movePaneToWorkspace) { [appModel] in
            guard appModel.focusDomain == .persistent,
                  let pane = appModel.persistentFocusedPane,
                  let workspace = appModel.selectedWorkspace else { return }
            appModel.movePaneToWorkspace(paneID: pane.id, workspaceID: workspace.id)
        }
        commandRegistry.register(.movePanelLeft) { [appModel] in appModel.setPanelPosition(.left) }
        commandRegistry.register(.movePanelRight) { [appModel] in appModel.setPanelPosition(.right) }
        commandRegistry.register(.movePanelTop) { [appModel] in appModel.setPanelPosition(.top) }
        commandRegistry.register(.movePanelBottom) { [appModel] in appModel.setPanelPosition(.bottom) }
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

        case let .claudeSessionDetected(paneID, sessionID):
            if let (_, pane) = appModel.findPane(id: paneID) {
                pane.claudeSessionID = sessionID
                appModel.debouncedSave()
            }

        case let .newSplit(paneID, direction, parentSurface):
            switch appModel.findPaneLocation(id: paneID) {
            case let .workspace(workspace, _):
                workspace.focusPane(id: paneID)
                if let newPane = workspace.splitFocusedPane(direction: direction) {
                    if let parentSurface {
                        GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                    }
                    appModel.saveWorkspaces()
                }
            case .persistent:
                Self.splitPersistentPane(appModel: appModel, direction: direction)
            case nil:
                break
            }

        case let .closeSurface(paneID):
            switch appModel.findPaneLocation(id: paneID) {
            case let .workspace(workspace, pane):
                let repoRoot = pane.repoRoot
                GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                workspace.removePane(id: paneID)
                appModel.saveWorkspaces()
                if let root = repoRoot {
                    Self.cleanupHeadWatcher(headWatcher, repoRoot: root, appModel: appModel)
                }
            case .persistent:
                GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                appModel.removePersistentPane(id: paneID)
            case nil:
                break
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

    private static func cleanupHeadWatcher(_ watcher: GitHEADWatcher, repoRoot: String, appModel: AppModel) {
        let hasRemainingPanes = appModel.workspaces.contains { workspace in
            workspace.allPanes.contains { $0.repoRoot == repoRoot }
        }
        if !hasRemainingPanes {
            watcher.stopWatching(repoRoot: repoRoot)
        }
    }

    private static func splitPane(appModel: AppModel, direction: SplitDirection, placeBefore: Bool = false) {
        if appModel.focusDomain == .persistent {
            splitPersistentPane(appModel: appModel, direction: direction, placeBefore: placeBefore)
        } else {
            splitWorkspacePane(appModel: appModel, direction: direction, placeBefore: placeBefore)
        }
    }

    private static func splitWorkspacePane(appModel: AppModel, direction: SplitDirection, placeBefore: Bool = false) {
        guard let workspace = appModel.selectedWorkspace else { return }
        let parentSurface = GhosttyApp.shared.focusedSurface
        if let newPane = workspace.splitFocusedPane(direction: direction, placeBefore: placeBefore) {
            if let parentSurface {
                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
            }
            appModel.saveWorkspaces()
        }
    }

    private static func splitPersistentPane(appModel: AppModel, direction: SplitDirection, placeBefore: Bool = false) {
        let parentSurface = GhosttyApp.shared.focusedSurface
        if let newPane = appModel.splitPersistentPane(direction: direction, placeBefore: placeBefore) {
            if let parentSurface {
                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
            }
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
            }
            CommandMenu("View") {
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

                Button(appModel.persistentPanelVisible ? "Hide Docked Panel" : "Show Docked Panel") {
                    commandRegistry.execute(.toggleDockedPanel)
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                Button(AppCommand.focusDockedPanel.title) {
                    commandRegistry.execute(.focusDockedPanel)
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
            CommandMenu("Shell") {
                Button(AppCommand.newWorkspace.title) {
                    commandRegistry.execute(.newWorkspace)
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button(AppCommand.splitRight.title) {
                    commandRegistry.execute(.splitRight)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button(AppCommand.splitDown.title) {
                    commandRegistry.execute(.splitDown)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button(AppCommand.splitLeft.title) {
                    commandRegistry.execute(.splitLeft)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Button(AppCommand.splitUp.title) {
                    commandRegistry.execute(.splitUp)
                }
                .keyboardShortcut("d", modifiers: [.command, .option, .shift])

                Divider()

                Button(AppCommand.equalizeSplits.title) {
                    commandRegistry.execute(.equalizeSplits)
                }
                .keyboardShortcut("=", modifiers: [.control, .shift])

                Divider()

                Button(AppCommand.flagPane.title) {
                    commandRegistry.execute(.flagPane)
                }
                .keyboardShortcut("g", modifiers: [.control, .shift])

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
            }
            CommandMenu("Theme") {
                Button(AppCommand.changeTheme.title) {
                    commandRegistry.execute(.changeTheme)
                }
            }
        }
    }
}
