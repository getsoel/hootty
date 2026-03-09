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

    private func splitFocusedPane(direction: SplitDirection, placeBefore: Bool = false) {
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
                        let workspace = appModel.addWorkspace()
                        appModel.selectedWorkspaceID = workspace.id
                    }
                    GhosttyApp.shared.onPaneNeedsAttention = { [appModel] paneID, kind in
                        appModel.handlePaneNeedsAttention(paneID, kind: kind)
                    }
                    GhosttyApp.shared.onPaneThinkingChanged = { [appModel] paneID, isThinking in
                        appModel.handlePaneThinkingChanged(paneID, isThinking: isThinking)
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
                    GhosttyApp.shared.onPwdChanged = { [appModel] _, _ in
                        appModel.debouncedSave()
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
            CommandMenu("View") {
                Button(appModel.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    appModel.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Shell") {
                Button("New Workspace") {
                    let workspace = appModel.addWorkspace()
                    appModel.selectedWorkspaceID = workspace.id
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Split Right") {
                    splitFocusedPane(direction: .horizontal)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Down") {
                    splitFocusedPane(direction: .vertical)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Split Left") {
                    splitFocusedPane(direction: .horizontal, placeBefore: true)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Button("Split Up") {
                    splitFocusedPane(direction: .vertical, placeBefore: true)
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
