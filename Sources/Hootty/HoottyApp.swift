import SwiftUI
import HoottyCore

@main
struct HoottyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        CrashHandler.install()
        Log.lifecycle.info("Hootty starting...")

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
        registerCommands()
    }

    @State private var appModel: AppModel
    @State private var commandRegistry: CommandRegistry

    // MARK: - Command Registration

    private func registerCommands() {
        commandRegistry.register(.newWorkspace) { [appModel] in
            let workspace = appModel.addWorkspace()
            appModel.selectedWorkspaceID = workspace.id
        }
        commandRegistry.register(.closeWorkspace) { [appModel] in
            guard let workspace = appModel.selectedWorkspace else { return }
            let id = workspace.id
            GhosttyApp.shared.cleanupWorkspace(workspace)
            appModel.removeWorkspace(id: id)
            if appModel.selectedWorkspaceID == id {
                appModel.selectedWorkspaceID = appModel.workspaces.first?.id
            }
        }
        commandRegistry.register(.splitRight) { [appModel] in
            Self.splitFocusedPane(appModel: appModel, direction: .horizontal)
        }
        commandRegistry.register(.splitDown) { [appModel] in
            Self.splitFocusedPane(appModel: appModel, direction: .vertical)
        }
        commandRegistry.register(.splitLeft) { [appModel] in
            Self.splitFocusedPane(appModel: appModel, direction: .horizontal, placeBefore: true)
        }
        commandRegistry.register(.splitUp) { [appModel] in
            Self.splitFocusedPane(appModel: appModel, direction: .vertical, placeBefore: true)
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
            appModel.selectedWorkspace?.focusPaneInDirection(.up)
        }
        commandRegistry.register(.focusPaneDown) { [appModel] in
            appModel.selectedWorkspace?.focusPaneInDirection(.down)
        }
        commandRegistry.register(.focusPaneLeft) { [appModel] in
            appModel.selectedWorkspace?.focusPaneInDirection(.left)
        }
        commandRegistry.register(.focusPaneRight) { [appModel] in
            appModel.selectedWorkspace?.focusPaneInDirection(.right)
        }
        commandRegistry.register(.equalizeSplits) { [appModel] in
            appModel.selectedWorkspace?.equalizeSplits()
        }
        commandRegistry.register(.toggleSidebar) { [appModel] in
            appModel.toggleSidebar()
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
        commandRegistry.register(.resetWorkspaces) { [appModel] in
            appModel.resetWorkspaces()
        }
        commandRegistry.register(.editConfig) { [appModel] in
            appModel.configFile.ensureExists()
            NSWorkspace.shared.open(ConfigFile.defaultFileURL)
        }

        // Wire the registry into GhosttyApp for action callback routing
        GhosttyApp.shared.commandRegistry = commandRegistry
    }

    private static func splitFocusedPane(appModel: AppModel, direction: SplitDirection, placeBefore: Bool = false) {
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
            ContentView(appModel: appModel, commandRegistry: commandRegistry)
                .frame(minWidth: 700, minHeight: 400)
                .onAppear {
                    if GhosttyApp.shared.onNewTab == nil {
                        NotificationCenter.default.addObserver(
                            forName: NSApplication.willTerminateNotification,
                            object: nil,
                            queue: .main
                        ) { [appModel] _ in
                            appModel.saveWorkspaces()
                        }
                    }

                    GhosttyApp.shared.onNewTab = { [appModel] in
                        let workspace = appModel.addWorkspace()
                        appModel.selectedWorkspaceID = workspace.id
                    }
                    GhosttyApp.shared.onBellRang = { [appModel] paneID in
                        let didSet = appModel.handleBell(paneID)
                        if didSet {
                            appModel.soundManager.play(.bell)
                        }
                    }
                    GhosttyApp.shared.onPaneNeedsAttention = { [appModel] paneID, kind in
                        let didSet = appModel.handlePaneNeedsAttention(paneID, kind: kind)
                        if didSet {
                            appModel.soundManager.play(.bell)
                        }
                    }
                    GhosttyApp.shared.onClaudeSessionDetected = { [appModel] paneID, sessionID in
                        if let (_, pane) = appModel.findPane(id: paneID) {
                            pane.claudeSessionID = sessionID
                            appModel.debouncedSave()
                        }
                    }
                    GhosttyApp.shared.onNewSplit = { [appModel] paneID, direction, parentSurface in
                        guard let (workspace, _) = appModel.findPane(id: paneID) else { return }
                        workspace.focusPane(id: paneID)
                        if let newPane = workspace.splitFocusedPane(direction: direction) {
                            if let parentSurface {
                                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                            }
                            appModel.saveWorkspaces()
                        }
                    }
                    GhosttyApp.shared.onCloseSurface = { [appModel] paneID in
                        GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                        guard let (workspace, _) = appModel.findPane(id: paneID) else { return }
                        workspace.removePane(id: paneID)
                        appModel.saveWorkspaces()
                    }
                    GhosttyApp.shared.onTitleChanged = { [appModel] paneID, title in
                        appModel.handleTitleChange(paneID, title: title)
                    }
                    GhosttyApp.shared.onPwdChanged = { [appModel] paneID, pwd in
                        appModel.handlePwdChanged(paneID, pwd: pwd)
                    }
                    GhosttyApp.shared.onCommandFinished = { paneID, exitCode in
                        if exitCode > 128 {
                            Log.lifecycle.info("Command in pane \(paneID) killed by signal \(exitCode - 128)")
                        }
                    }
                    GhosttyApp.shared.onCloseTab = { [appModel] in
                        guard let workspace = appModel.selectedWorkspace,
                              let focusedPaneID = workspace.focusedPaneID else { return }
                        GhosttyApp.shared.removeCachedSurfaceView(for: focusedPaneID)
                        workspace.removePane(id: focusedPaneID)
                        appModel.saveWorkspaces()
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

                Button(appModel.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    commandRegistry.execute(.toggleSidebar)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
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
