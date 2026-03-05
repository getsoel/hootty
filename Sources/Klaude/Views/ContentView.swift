import AppKit
import SwiftUI
import KlaudeCore

struct ContentView: View {
    var appModel: AppModel

    private var selectedWorkspace: Workspace? {
        appModel.selectedWorkspace
    }

    private var theme: TerminalTheme {
        appModel.themeManager.theme
    }

    private var flavor: CatppuccinFlavor {
        appModel.themeManager.selectedFlavor
    }

    var body: some View {
        HStack(spacing: 0) {
            if appModel.sidebarVisible {
                WorkspaceSidebar(
                    workspaces: appModel.workspaces,
                    selectedWorkspaceID: Binding(
                        get: { appModel.selectedWorkspaceID },
                        set: { appModel.selectedWorkspaceID = $0 }
                    ),
                    theme: theme,
                    onAddWorkspace: {
                        let workspace = appModel.addWorkspace()
                        appModel.selectedWorkspaceID = workspace.id
                    },
                    onRemoveWorkspace: { id in
                        appModel.removeWorkspace(id: id)
                        if appModel.selectedWorkspaceID == id {
                            appModel.selectedWorkspaceID = appModel.workspaces.first?.id
                        }
                    },
                    onSelectTab: { workspaceID, tabID in
                        appModel.selectedWorkspaceID = workspaceID
                        if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                            workspace.selectTab(id: tabID)
                        }
                    },
                    onAddTab: { workspaceID in
                        if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                            workspace.addTab()
                        }
                    },
                    onRemoveTab: { workspaceID, tabID in
                        if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                            workspace.removeTab(id: tabID)
                        }
                    }
                )
                .transition(.move(edge: .leading))

                // Divider between sidebar and terminal
                Rectangle()
                    .fill(Color(theme.sidebarSurface))
                    .frame(width: 1)
            }

            // Detail view
            if let workspace = selectedWorkspace {
                VStack(spacing: 0) {
                    if workspace.tabs.count > 1 {
                        TabBar(
                            workspace: workspace,
                            theme: theme,
                            onAddTab: { workspace.addTab() }
                        )

                        Rectangle()
                            .fill(Color(theme.sidebarSurface))
                            .frame(height: 1)
                    }

                    // Terminal surfaces — ZStack keeps all tabs alive
                    ZStack {
                        ForEach(workspace.tabs) { tab in
                            TerminalPanel(tab: tab)
                                .opacity(tab.id == workspace.selectedTabID ? 1 : 0)
                                .allowsHitTesting(tab.id == workspace.selectedTabID)
                        }
                    }
                }
                .id(workspace.id)
            } else {
                Text("Select or create a workspace")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(theme.background).ignoresSafeArea())
        .background(
            WindowAccessor { window in
                window.isOpaque = true
                window.backgroundColor = theme.background
                window.appearance = NSAppearance(named: flavor.isLight ? .aqua : .darkAqua)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: appModel.sidebarVisible)
    }
}
