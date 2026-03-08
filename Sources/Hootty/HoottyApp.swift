import SwiftUI
import HoottyCore

@main
struct HoottyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        CrashHandler.install()
        Log.lifecycle.info("Hootty starting...")

        // Initialize the ghostty backend (singleton)
        if GhosttyApp.shared.app != nil {
            Log.lifecycle.info("Ghostty backend initialized")
        } else {
            Log.lifecycle.error("Ghostty backend failed to initialize")
        }
    }

    @State private var appModel = AppModel()

    private func splitFocusedGroup(direction: SplitDirection, placeBefore: Bool = false) {
        guard let workspace = appModel.selectedWorkspace else { return }

        let parentSurface = GhosttyApp.shared.focusedSurface

        if let newGroup = workspace.splitFocusedGroup(direction: direction, placeBefore: placeBefore) {
            if let parentSurface, let newPane = newGroup.panes.first {
                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
            }
            appModel.saveWorkspaces()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
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
                        appModel.selectedWorkspace?.addPaneToFocusedGroup()
                        appModel.saveWorkspaces()
                    }
                    GhosttyApp.shared.onPaneNeedsAttention = { [appModel] paneID in
                        appModel.handlePaneNeedsAttention(paneID)
                    }
                    GhosttyApp.shared.onClaudeSessionDetected = { [appModel] paneID, sessionID in
                        if let (_, _, pane) = appModel.findPane(id: paneID) {
                            pane.claudeSessionID = sessionID
                            appModel.debouncedSave()
                        }
                    }
                    GhosttyApp.shared.onNewSplit = { [appModel] paneID, direction, parentSurface in
                        guard let (workspace, group, _) = appModel.findPane(id: paneID) else { return }
                        workspace.focusPaneGroup(id: group.id)
                        if let newGroup = workspace.splitFocusedGroup(direction: direction) {
                            if let parentSurface, let newPane = newGroup.panes.first {
                                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                            }
                            appModel.saveWorkspaces()
                        }
                    }
                    GhosttyApp.shared.onCloseSurface = { [appModel] paneID in
                        GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                        guard let (workspace, _, _) = appModel.findPane(id: paneID) else { return }
                        workspace.closePane(id: paneID)
                        appModel.saveWorkspaces()
                    }
                    GhosttyApp.shared.onPwdChanged = { [appModel] _, _ in
                        appModel.debouncedSave()
                    }
                    GhosttyApp.shared.onCloseTab = { [appModel] in
                        guard let workspace = appModel.selectedWorkspace,
                              let group = workspace.focusedPaneGroup,
                              let selectedPaneID = group.selectedPaneID else { return }
                        GhosttyApp.shared.removeCachedSurfaceView(for: selectedPaneID)
                        workspace.closePane(id: selectedPaneID)
                        appModel.saveWorkspaces()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("View") {
                Button(appModel.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    appModel.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Shell") {
                Button("New Tab") {
                    appModel.selectedWorkspace?.addPaneToFocusedGroup()
                    appModel.saveWorkspaces()
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Split Right") {
                    splitFocusedGroup(direction: .horizontal)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Down") {
                    splitFocusedGroup(direction: .vertical)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Split Left") {
                    splitFocusedGroup(direction: .horizontal, placeBefore: true)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Button("Split Up") {
                    splitFocusedGroup(direction: .vertical, placeBefore: true)
                }
                .keyboardShortcut("d", modifiers: [.command, .option, .shift])
            }
            CommandMenu("Theme") {
                ForEach(CatppuccinFlavor.allCases, id: \.self) { flavor in
                    Button {
                        appModel.themeManager.selectedFlavor = flavor
                        GhosttyApp.shared.reloadConfig(theme: appModel.themeManager.theme)
                    } label: {
                        if appModel.themeManager.selectedFlavor == flavor {
                            Text("\(flavor.displayName) ✓")
                        } else {
                            Text(flavor.displayName)
                        }
                    }
                }
            }
        }
    }
}
