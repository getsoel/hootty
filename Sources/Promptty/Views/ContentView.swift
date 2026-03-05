import AppKit
import SwiftUI
import PrompttyCore

struct ContentView: View {
    var appModel: AppModel
    @GestureState private var dragOffset: CGFloat = 0

    private var selectedWorkspace: Workspace? {
        appModel.selectedWorkspace
    }

    private var theme: TerminalTheme {
        appModel.themeManager.theme
    }

    private var flavor: CatppuccinFlavor {
        appModel.themeManager.selectedFlavor
    }

    /// Effective sidebar width: base + in-flight drag delta, clamped to bounds.
    private var effectiveSidebarWidth: CGFloat {
        let w = appModel.sidebarWidth + dragOffset
        return min(max(w, AppModel.sidebarMinWidth), AppModel.sidebarMaxWidth)
    }

    var body: some View {
        GeometryReader { geometry in
            let sidebarW = appModel.sidebarVisible ? effectiveSidebarWidth : 0
            let dividerW: CGFloat = appModel.sidebarVisible ? 1 : 0
            let detailX = sidebarW + dividerW
            let fullWidth = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing

            ZStack(alignment: .topLeading) {
                // Sidebar
                if appModel.sidebarVisible {
                    sidebar
                        .frame(width: sidebarW, height: geometry.size.height)

                    // Visible 1px divider line
                    Rectangle()
                        .fill(Color(theme.sidebarSurface))
                        .frame(width: 1, height: geometry.size.height)
                        .offset(x: sidebarW)

                    // Invisible wide drag handle overlaying the divider
                    Color.clear
                        .frame(width: 9, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .offset(x: sidebarW - 4)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation.width
                                }
                                .onEnded { value in
                                    let newWidth = appModel.sidebarWidth + value.translation.width
                                    appModel.sidebarWidth = min(
                                        max(newWidth, AppModel.sidebarMinWidth),
                                        AppModel.sidebarMaxWidth
                                    )
                                }
                        )
                }

                // Detail area
                detailView
                    .frame(
                        width: max(0, fullWidth - detailX),
                        height: geometry.size.height
                    )
                    .offset(x: detailX)
            }
            .frame(width: fullWidth, alignment: .topLeading)
            .clipped()
        }
        .background(Color(theme.background).ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            Rectangle()
                .fill(Color(theme.sidebarSurface))
                .frame(height: 1)
        }
        .background(
            WindowAccessor { window in
                window.isOpaque = true
                window.backgroundColor = theme.background
                window.appearance = NSAppearance(named: flavor.isLight ? .aqua : .darkAqua)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: appModel.sidebarVisible)
    }

    private var sidebar: some View {
        WorkspaceSidebar(
            workspaces: appModel.workspaces,
            selectedWorkspaceID: Binding(
                get: { appModel.selectedWorkspaceID },
                set: { appModel.selectedWorkspaceID = $0 }
            ),
            theme: theme,
            isKanbanSelected: appModel.viewMode == .kanban,
            onSelectKanban: {
                appModel.viewMode = .kanban
            },
            onAddWorkspace: {
                let workspace = appModel.addWorkspace()
                appModel.selectedWorkspaceID = workspace.id
                appModel.viewMode = .terminal
            },
            onRemoveWorkspace: { id in
                appModel.removeWorkspace(id: id)
                if appModel.selectedWorkspaceID == id {
                    appModel.selectedWorkspaceID = appModel.workspaces.first?.id
                }
            },
            onSelectTab: { workspaceID, tabID in
                appModel.selectedWorkspaceID = workspaceID
                appModel.viewMode = .terminal
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.selectTab(id: tabID)
                }
            },
            onSelectPane: { workspaceID, tabID, paneID in
                appModel.selectedWorkspaceID = workspaceID
                appModel.viewMode = .terminal
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.selectTab(id: tabID)
                    if let tab = workspace.tabs.first(where: { $0.id == tabID }) {
                        tab.focusPane(id: paneID)
                    }
                }
            },
            onAddTab: { workspaceID in
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.addTab()
                    appModel.saveWorkspaces()
                }
            },
            onRemoveTab: { workspaceID, tabID in
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.removeTab(id: tabID)
                    appModel.saveWorkspaces()
                }
            },
            onRemovePane: { workspaceID, tabID, paneID in
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }),
                   let tab = workspace.tabs.first(where: { $0.id == tabID }) {
                    tab.removePane(id: paneID)
                    appModel.saveWorkspaces()
                }
            },
            onSave: { appModel.saveWorkspaces() },
            sidebarWidth: effectiveSidebarWidth
        )
    }

    private func emptyWorkspaceView(workspace: Workspace) -> some View {
        VStack(spacing: 12) {
            Text("No open tabs")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("New Tab") {
                workspace.addTab()
                appModel.saveWorkspaces()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appModel.viewMode {
        case .kanban:
            KanbanBoardView(store: appModel.kanbanStore, theme: theme)

        case .terminal:
            if let workspace = selectedWorkspace {
                if workspace.tabs.isEmpty {
                    emptyWorkspaceView(workspace: workspace)
                } else {
                    VStack(spacing: 0) {
                        if workspace.tabs.count > 1 {
                            TabBar(
                                workspace: workspace,
                                theme: theme,
                                onAddTab: { workspace.addTab(); appModel.saveWorkspaces() },
                                onSave: { appModel.saveWorkspaces() }
                            )

                            Rectangle()
                                .fill(Color(theme.sidebarSurface))
                                .frame(height: 1)
                        }

                        // Terminal surfaces — ZStack keeps all tabs alive
                        ZStack {
                            ForEach(workspace.tabs) { tab in
                                SplitNodeView(
                                    node: tab.rootNode,
                                    focusedPaneID: tab.focusedPaneID,
                                    onFocusPane: { paneID in tab.focusPane(id: paneID) }
                                )
                                .opacity(tab.id == workspace.selectedTabID ? 1 : 0)
                                .allowsHitTesting(tab.id == workspace.selectedTabID)
                            }
                        }
                    }
                    .id(workspace.id)
                }
            } else {
                Text("Select or create a workspace")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
