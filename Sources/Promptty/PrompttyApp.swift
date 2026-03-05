import SwiftUI
import PrompttyCore

@main
struct PrompttyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        CrashHandler.install()
        Log.lifecycle.info("Promptty starting...")

        // Initialize the ghostty backend (singleton)
        if GhosttyApp.shared.app != nil {
            Log.lifecycle.info("Ghostty backend initialized")
        } else {
            Log.lifecycle.error("Ghostty backend failed to initialize")
        }
    }

    @State private var appModel = AppModel()

    private func splitFocusedPane(direction: SplitDirection) {
        guard let workspace = appModel.selectedWorkspace,
              let tab = workspace.selectedTab,
              let paneID = tab.focusedPaneID else { return }

        // Get parent surface for inherited config
        let parentSurface = GhosttyApp.shared.focusedSurface

        if let newPane = tab.splitPane(paneID: paneID, direction: direction) {
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
                    // willTerminateNotification fires once at app exit; guard
                    // against duplicate observers if SwiftUI re-creates the view.
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
                        appModel.selectedWorkspace?.addTab()
                        appModel.saveWorkspaces()
                    }
                    GhosttyApp.shared.onPaneNeedsAttention = { [appModel] paneID in
                        appModel.handlePaneNeedsAttention(paneID)
                    }
                    GhosttyApp.shared.onNewSplit = { [appModel] paneID, direction, parentSurface in
                        guard let (_, tab, _) = appModel.findPane(id: paneID) else { return }
                        if let newPane = tab.splitPane(paneID: paneID, direction: direction) {
                            if let parentSurface {
                                GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                            }
                            appModel.saveWorkspaces()
                        }
                    }
                    GhosttyApp.shared.onCloseSurface = { [appModel] paneID in
                        guard let (workspace, tab, _) = appModel.findPane(id: paneID) else { return }
                        if tab.allPanes.count > 1 {
                            tab.removePane(id: paneID)
                        } else {
                            workspace.removeTab(id: tab.id)
                        }
                        appModel.saveWorkspaces()
                    }
                    GhosttyApp.shared.onCloseTab = { [appModel] in
                        guard let workspace = appModel.selectedWorkspace,
                              let tab = workspace.selectedTab else { return }
                        workspace.removeTab(id: tab.id)
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
                    appModel.selectedWorkspace?.addTab()
                    appModel.saveWorkspaces()
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
            }
            CommandMenu("Theme") {
                ForEach(CatppuccinFlavor.allCases, id: \.self) { flavor in
                    Button {
                        appModel.themeManager.selectedFlavor = flavor
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
