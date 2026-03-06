import AppKit
import SwiftUI
import HoottyCore

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
            onSelectPaneGroup: { workspaceID, groupID in
                appModel.selectedWorkspaceID = workspaceID
                appModel.viewMode = .terminal
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.focusPaneGroup(id: groupID)
                }
            },
            onSelectPane: { workspaceID, paneID in
                appModel.selectedWorkspaceID = workspaceID
                appModel.viewMode = .terminal
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.focusPane(id: paneID)
                }
            },
            onRemovePaneGroup: { workspaceID, groupID in
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.removePaneGroup(id: groupID)
                    appModel.saveWorkspaces()
                }
            },
            onRemovePane: { workspaceID, paneID in
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.closePane(id: paneID)
                    appModel.saveWorkspaces()
                }
            },
            onSave: { appModel.saveWorkspaces() },
            sidebarWidth: effectiveSidebarWidth
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch appModel.viewMode {
        case .kanban:
            KanbanBoardView(store: appModel.kanbanStore, theme: theme)

        case .terminal:
            if let workspace = selectedWorkspace {
                SplitNodeView(
                    node: workspace.rootNode,
                    focusedPaneGroupID: workspace.focusedPaneGroupID,
                    theme: theme,
                    isInSplit: false,
                    onFocusPaneGroup: { groupID in
                        workspace.focusPaneGroup(id: groupID)
                    },
                    onAddPane: { groupID in
                        workspace.focusPaneGroup(id: groupID)
                        workspace.addPaneToFocusedGroup()
                        appModel.saveWorkspaces()
                    },
                    onRemovePane: { paneID in
                        workspace.closePane(id: paneID)
                        appModel.saveWorkspaces()
                    },
                    onSave: { appModel.saveWorkspaces() }
                )
                .id(workspace.id)
            } else {
                Text("Select or create a workspace")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
