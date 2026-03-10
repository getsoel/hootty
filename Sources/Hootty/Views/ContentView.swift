import SwiftUI
import HoottyCore

struct ContentView: View {
    @Bindable var appModel: AppModel
    var commandRegistry: CommandRegistry
    @GestureState private var dragOffset: CGFloat = 0
    @State private var prePickerTheme: (name: String, theme: TerminalTheme)?

    private var selectedWorkspace: Workspace? {
        appModel.selectedWorkspace
    }

    private var theme: TerminalTheme {
        appModel.themeManager.theme
    }

    private var tokens: DesignTokens {
        DesignTokens.from(theme)
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
                        .fill(Color(tokens.border))
                        .frame(width: 1, height: geometry.size.height)
                        .offset(x: sidebarW)

                    // Invisible wide drag handle overlaying the divider
                    Color.clear
                        .frame(width: 16, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .offset(x: sidebarW - 7.5)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                DispatchQueue.main.async {
                                    NSCursor.resizeLeftRight.set()
                                }
                            case .ended:
                                DispatchQueue.main.async {
                                    NSCursor.arrow.set()
                                }
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
                                    appModel.debouncedSave()
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
        .background(Color(tokens.surface), ignoresSafeAreaEdges: [])
        .background(Color(tokens.background))
        .safeAreaInset(edge: .top, spacing: 0) {
            Rectangle()
                .fill(Color(tokens.border))
                .frame(height: 1)
        }
        .background(
            WindowAccessor { window in
                window.isOpaque = true
                window.backgroundColor = tokens.background
                window.appearance = NSAppearance(named: theme.isLight ? .aqua : .darkAqua)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: appModel.sidebarVisible)
        .overlay {
            if appModel.modalState == .commandPalette {
                CommandPaletteView(
                    tokens: tokens,
                    commands: commandRegistry.paletteCommands,
                    onDismiss: { appModel.modalState = .none }
                )
            }
        }
        .overlay {
            if appModel.modalState == .themePicker {
                ThemePickerView(
                    tokens: tokens,
                    themePreviews: appModel.themeManager.themeCatalog.themePreviews,
                    selectedThemeName: appModel.themeManager.selectedThemeName,
                    onSelectTheme: { name in
                        prePickerTheme = nil
                        appModel.themeManager.selectedThemeName = name
                        let content = appModel.configFile.ghosttyConfigContent()
                        if let resolved = GhosttyApp.shared.reloadConfig(ghosttyContent: content) {
                            appModel.themeManager.setResolvedTheme(resolved)
                        }
                        appModel.modalState = .none
                    },
                    onPreview: { name in
                        if let content = appModel.themeManager.themeCatalog.themeContent(for: name),
                           let parsed = TerminalTheme.parse(ghosttyThemeContent: content) {
                            appModel.themeManager.setResolvedTheme(parsed)
                        }
                    },
                    onDismiss: {
                        if let saved = prePickerTheme {
                            appModel.themeManager.setResolvedTheme(saved.theme)
                        }
                        prePickerTheme = nil
                        appModel.modalState = .none
                    }
                )
            }
        }
        .onChange(of: appModel.modalState) { _, state in
            if state == .themePicker {
                appModel.themeManager.themeCatalog.loadPreviews()
                prePickerTheme = (
                    name: appModel.themeManager.selectedThemeName,
                    theme: appModel.themeManager.theme
                )
            }
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(
            workspaces: appModel.workspaces,
            selectedWorkspaceID: $appModel.selectedWorkspaceID,
            tokens: tokens,
            isLight: theme.isLight,
            onAddWorkspace: {
                let workspace = appModel.addWorkspace()
                appModel.selectedWorkspaceID = workspace.id
            },
            onRemoveWorkspace: { id in
                if let workspace = appModel.workspaces.first(where: { $0.id == id }) {
                    GhosttyApp.shared.cleanupWorkspace(workspace)
                }
                appModel.removeWorkspace(id: id)
                if appModel.selectedWorkspaceID == id {
                    appModel.selectedWorkspaceID = appModel.workspaces.first?.id
                }
            },
            onMoveWorkspace: { id, toIndex in
                appModel.moveWorkspace(id: id, toIndex: toIndex)
            },
            onSelectPane: { workspaceID, paneID in
                appModel.selectedWorkspaceID = workspaceID
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    workspace.focusPane(id: paneID)
                }
            },
            onRemovePane: { workspaceID, paneID in
                if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
                    GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                    workspace.removePane(id: paneID)
                    appModel.saveWorkspaces()
                }
            },
            onSave: { appModel.saveWorkspaces() },
            sidebarWidth: effectiveSidebarWidth
        )
    }

    @ViewBuilder
    private var detailView: some View {
        if let workspace = selectedWorkspace {
            SplitNodeView(
                node: workspace.rootNode,
                focusedPaneID: workspace.focusedPaneID,
                tokens: tokens,
                isInSplit: false,
                onFocusPane: { paneID in
                    workspace.focusPane(id: paneID)
                },
                onSplitPane: { direction, placeBefore in
                    let parentSurface = GhosttyApp.shared.focusedSurface
                    if let newPane = workspace.splitFocusedPane(direction: direction, placeBefore: placeBefore) {
                        if let parentSurface {
                            GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                        }
                        appModel.saveWorkspaces()
                    }
                },
                onClosePane: { paneID in
                    GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                    workspace.removePane(id: paneID)
                    appModel.saveWorkspaces()
                },
                onSave: { appModel.saveWorkspaces() }
            )
            .id(workspace.id)
        } else {
            Text("Select or create a workspace")
                .foregroundStyle(Color(tokens.textMuted))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
