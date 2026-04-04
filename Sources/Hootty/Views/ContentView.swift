import HoottyCore
import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppModel
    var commandRegistry: CommandRegistry
    /// Called after pane/workspace removal to clean up file watchers for a repo root.
    var onCleanupRepoWatchers: ((String) -> Void)?
    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var panelDragOffset: CGFloat = 0
    @State private var prePickerTheme: (name: String, theme: TerminalTheme)?
    @State private var sidebarCursorTarget: SidebarCursorTarget?
    @State private var memoryMonitor = MemoryMonitor()

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

    /// Effective persistent panel width: base - in-flight drag delta (drag left = wider), clamped.
    private var effectivePanelWidth: CGFloat {
        let w = appModel.persistentPanelWidth - panelDragOffset
        return min(max(w, AppModel.persistentPanelMinWidth), AppModel.persistentPanelMaxWidth)
    }

    private var panelVisible: Bool {
        appModel.persistentPanelVisible && appModel.persistentNode != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            mainContent
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(tokens.surface), ignoresSafeAreaEdges: [])
        .background(Color(tokens.background))
        .background(
            WindowAccessor { window in
                window.isOpaque = true
                window.backgroundColor = tokens.background
                window.appearance = NSAppearance(named: theme.isLight ? .aqua : .darkAqua)

                // Vertically center traffic lights in the bar.
                // Use Auto Layout constraints on each button — persists across
                // window move/resize/fullscreen unlike setFrameOrigin.
                Self.repositionTrafficLights(in: window)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: appModel.sidebarMode)
        .animation(.easeInOut(duration: 0.2), value: panelVisible)
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
                        applyTheme(name: name)
                        appModel.modalState = .none
                    },
                    onPreview: { name in
                        applyTheme(name: name)
                    },
                    onDismiss: {
                        if let saved = prePickerTheme {
                            applyTheme(name: saved.name, fallback: saved.theme)
                        }
                        prePickerTheme = nil
                        appModel.modalState = .none
                    }
                )
            }
        }
        .overlay {
            if appModel.modalState == .attentionSounds {
                AttentionSoundsView(
                    soundManager: appModel.soundManager,
                    tokens: tokens,
                    onDismiss: { appModel.modalState = .none }
                )
            }
        }
        .overlay {
            if appModel.modalState == .memoryLog {
                ActivityMonitorView(
                    tokens: tokens,
                    samples: memoryMonitor.samples,
                    appModel: appModel,
                    onDismiss: { appModel.modalState = .none }
                )
            }
        }
        .overlay {
            if case let .noteEditor(paneID) = appModel.modalState,
               let (_, pane) = appModel.findPane(id: paneID) {
                ZStack {
                    Color(tokens.scrim)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { appModel.modalState = .none }

                    PaneNoteEditor(pane: pane, tokens: tokens, onDismiss: { appModel.modalState = .none })
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 60)
                }
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

    @ViewBuilder
    private var sidebarContent: some View {
        switch appModel.sidebarMode {
        case .full:
            sidebar
        case .condensed:
            condensedSidebar
        case .hidden:
            EmptyView()
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(
            workspaces: appModel.workspaces,
            selectedWorkspaceID: $appModel.selectedWorkspaceID,
            tokens: tokens,
            onAddWorkspace: handleAddWorkspace,
            onRemoveWorkspace: handleRemoveWorkspace,
            onMoveWorkspace: { id, toIndex in
                appModel.moveWorkspace(id: id, toIndex: toIndex)
            },
            onSelectPane: handleSelectPane,
            onRemovePane: handleRemovePane,
            onToggleNote: { paneID in
                appModel.modalState = .noteEditor(paneID)
            },
            onToggleCollapse: { id in
                appModel.toggleWorkspaceCollapse(id)
            },
            onSave: { appModel.saveWorkspaces() },
            sidebarHasFocus: $appModel.sidebarHasFocus,
            sidebarCursorTarget: $sidebarCursorTarget,
            sidebarWidth: effectiveSidebarWidth,
            isEffectivelyCollapsed: { appModel.isWorkspaceEffectivelyCollapsed($0) },
            showLayoutThumbnails: $appModel.showLayoutThumbnails,
            collapsedWorkspaceIDs: appModel.collapsedWorkspaceIDs,
            activeSidebarFilters: appModel.activeSidebarFilters,
            onToggleSidebarFilter: { appModel.toggleSidebarFilter($0) },
            onClearSidebarFilters: { appModel.clearSidebarFilters() },
            persistentNode: appModel.persistentNode,
            persistentFocusedPaneID: appModel.persistentFocusedPaneID,
            persistentSidebarCollapsed: $appModel.persistentSidebarCollapsed,
            onSelectPersistentPane: handleSelectPersistentPane,
            onRemovePersistentPane: handleRemovePersistentPane,
            onNewPersistentPane: { appModel.addPersistentPane() },
            onCloseAllPersistentPanes: {
                if let node = appModel.persistentNode {
                    for pane in node.allPanes() {
                        GhosttyApp.shared.removeCachedSurfaceView(for: pane.id)
                    }
                }
                appModel.closePersistentPanel()
            },
            onMovePaneToWorkspace: { paneID, workspaceID in
                appModel.movePaneToWorkspace(paneID: paneID, workspaceID: workspaceID)
            },
            onMovePaneToPinned: { paneID in
                appModel.movePaneToPersistentPanel(paneID: paneID)
            }
        )
    }

    private var condensedSidebar: some View {
        CondensedSidebar(
            workspaces: appModel.workspaces,
            selectedWorkspaceID: $appModel.selectedWorkspaceID,
            tokens: tokens,
            onExpandSidebar: { appModel.sidebarMode = .full },
            onAddWorkspace: handleAddWorkspace,
            onRemoveWorkspace: handleRemoveWorkspace,
            onSelectPane: handleSelectPane,
            onRemovePane: handleRemovePane,
            onToggleCollapse: { id in
                withAnimation(.easeInOut(duration: 0.15)) {
                    appModel.toggleWorkspaceCollapse(id)
                }
            },
            onSave: { appModel.saveWorkspaces() },
            isEffectivelyCollapsed: { appModel.isWorkspaceEffectivelyCollapsed($0) },
            collapsedWorkspaceIDs: appModel.collapsedWorkspaceIDs,
            activeSidebarFilters: appModel.activeSidebarFilters,
            persistentNode: appModel.persistentNode,
            persistentFocusedPaneID: appModel.persistentFocusedPaneID,
            persistentSidebarCollapsed: $appModel.persistentSidebarCollapsed,
            onSelectPersistentPane: handleSelectPersistentPane,
            onRemovePersistentPane: handleRemovePersistentPane,
            onNewPersistentPane: { appModel.addPersistentPane() },
            onMovePaneToPinned: { paneID in
                appModel.movePaneToPersistentPanel(paneID: paneID)
            },
            onMovePaneToWorkspace: { paneID, workspaceID in
                appModel.movePaneToWorkspace(paneID: paneID, workspaceID: workspaceID)
            }
        )
    }

    // MARK: - Shared Sidebar Callbacks

    private func handleAddWorkspace() {
        let workspace = appModel.addWorkspace()
        appModel.selectedWorkspaceID = workspace.id
    }

    private func handleRemoveWorkspace(_ id: UUID) {
        let repoRoots: Set<String>
        if let workspace = appModel.workspaces.first(where: { $0.id == id }) {
            repoRoots = Set(workspace.allPanes.compactMap(\.repoRoot))
            GhosttyApp.shared.cleanupWorkspace(workspace)
        } else {
            repoRoots = []
        }
        appModel.removeWorkspace(id: id)
        if appModel.selectedWorkspaceID == id {
            appModel.selectedWorkspaceID = appModel.workspaces.first?.id
        }
        for root in repoRoots {
            onCleanupRepoWatchers?(root)
        }
    }

    private func handleSelectPane(_ workspaceID: UUID, _ paneID: UUID) {
        appModel.selectedWorkspaceID = workspaceID
        if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
            workspace.focusPane(id: paneID)
        }
    }

    private func handleRemovePane(_ workspaceID: UUID, _ paneID: UUID) {
        if let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }) {
            let repoRoot = workspace.findPane(id: paneID)?.repoRoot
            GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
            workspace.removePane(id: paneID)
            appModel.saveWorkspaces()
            if let root = repoRoot {
                onCleanupRepoWatchers?(root)
            }
        }
    }

    private func handleSelectPersistentPane(_ paneID: UUID) {
        appModel.sidebarHasFocus = false
        appModel.focusDomain = .persistent
        appModel.persistentFocusedPaneID = paneID
        appModel.persistentPanelVisible = true
    }

    private func handleRemovePersistentPane(_ paneID: UUID) {
        GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
        appModel.removePersistentPane(id: paneID)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Leave space for traffic lights
            Color.clear.frame(width: 78)

            Spacer()

            if memoryMonitor.memoryMB > 0 {
                Text("\(memoryMonitor.memoryMB) MB")
                    .font(.system(size: TypeScale.smallSize).monospacedDigit())
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
                    .contentShape(Rectangle())
                    .onTapGesture { appModel.modalState = .memoryLog }
            }
        }
        .padding(.trailing, Spacing.md)
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
        .task {
            memoryMonitor.recordSample(appModel: appModel)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                memoryMonitor.recordSample(appModel: appModel)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        workspacesContent
    }

    private var workspacesContent: some View {
        GeometryReader { geometry in
            let sidebarW: CGFloat = switch appModel.sidebarMode {
            case .full: effectiveSidebarWidth
            case .condensed: Layout.condensedSidebarWidth
            case .hidden: 0
            }
            let dividerW: CGFloat = appModel.sidebarMode != .hidden ? 1 : 0
            let detailX = sidebarW + dividerW
            let fullWidth = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
            let panelW = panelVisible ? effectivePanelWidth : 0
            let panelDividerW: CGFloat = panelVisible ? 1 : 0
            let detailW = max(0, fullWidth - detailX - panelW - panelDividerW)
            let panelDividerX = detailX + detailW
            let panelX = panelDividerX + panelDividerW

            ZStack(alignment: .topLeading) {
                // Sidebar
                if appModel.sidebarMode != .hidden {
                    sidebarContent
                        .frame(width: sidebarW, height: geometry.size.height)

                    // Visible 1px divider line
                    Rectangle()
                        .fill(Color(tokens.border))
                        .frame(width: 1, height: geometry.size.height)
                        .offset(x: sidebarW)

                    // Invisible wide drag handle overlaying the divider (full mode only)
                    if appModel.sidebarMode == .full {
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
                }

                // Detail area
                detailView
                    .frame(
                        width: detailW,
                        height: geometry.size.height
                    )
                    .offset(x: detailX)

                // Persistent panel
                if panelVisible {
                    // Visible 1px divider
                    Rectangle()
                        .fill(Color(tokens.border))
                        .frame(width: 1, height: geometry.size.height)
                        .offset(x: panelDividerX)

                    // Invisible wide drag handle
                    Color.clear
                        .frame(width: 16, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .offset(x: panelDividerX - 7.5)
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
                                .updating($panelDragOffset) { value, state, _ in
                                    state = value.translation.width
                                }
                                .onEnded { value in
                                    let newWidth = appModel.persistentPanelWidth - value.translation.width
                                    appModel.persistentPanelWidth = min(
                                        max(newWidth, AppModel.persistentPanelMinWidth),
                                        AppModel.persistentPanelMaxWidth
                                    )
                                    appModel.debouncedSave()
                                }
                        )

                    // Panel content
                    persistentPanelView
                        .frame(width: panelW, height: geometry.size.height)
                        .offset(x: panelX)
                }
            }
            .frame(width: fullWidth, alignment: .topLeading)
            .clipped()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let workspace = selectedWorkspace {
            terminalsDetail(workspace: workspace)
        } else {
            Text("Select or create a workspace")
                .foregroundStyle(Color(tokens.textMuted))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func terminalsDetail(workspace: Workspace) -> some View {
        SplitNodeView(
            node: workspace.rootNode,
            focusedPaneID: appModel.focusDomain == .workspace ? workspace.focusedPaneID : nil,
            tokens: tokens,
            isInSplit: false,
            onFocusPane: { paneID in
                appModel.sidebarHasFocus = false
                appModel.focusDomain = .workspace
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
                let repoRoot = workspace.findPane(id: paneID)?.repoRoot
                GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                workspace.removePane(id: paneID)
                appModel.saveWorkspaces()
                if let root = repoRoot {
                    onCleanupRepoWatchers?(root)
                }
            },
            onSwapPanes: { sourceID, targetID in
                workspace.swapPanes(sourceID, targetID)
                appModel.saveWorkspaces()
            },
            onToggleNote: { paneID in
                appModel.modalState = .noteEditor(paneID)
            },
            onToggleFlag: {
                workspace.focusedPane?.toggleFlag()
            },
            onSave: { appModel.saveWorkspaces() }
        )
        .environment(\.sidebarHasFocus, appModel.sidebarHasFocus)
        .environment(\.sidebarCursorPaneID, sidebarCursorTarget?.cursorPaneID)
        .environment(\.modalIsOpen, appModel.modalState != .none)
        .id(workspace.id)
    }

    @ViewBuilder
    private var persistentPanelView: some View {
        if let node = appModel.persistentNode {
            SplitNodeView(
                node: node,
                focusedPaneID: appModel.focusDomain == .persistent ? appModel.persistentFocusedPaneID : nil,
                tokens: tokens,
                isInSplit: false,
                onFocusPane: { paneID in
                    appModel.sidebarHasFocus = false
                    appModel.focusDomain = .persistent
                    appModel.persistentFocusedPaneID = paneID
                },
                onSplitPane: { direction, placeBefore in
                    let parentSurface = GhosttyApp.shared.focusedSurface
                    if let newPane = appModel.splitPersistentPane(direction: direction, placeBefore: placeBefore) {
                        if let parentSurface {
                            GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                        }
                    }
                },
                onClosePane: { paneID in
                    GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                    appModel.removePersistentPane(id: paneID)
                },
                onSwapPanes: { sourceID, targetID in
                    node.swapPanes(sourceID, targetID)
                    appModel.saveWorkspaces()
                },
                onToggleNote: { paneID in
                    appModel.modalState = .noteEditor(paneID)
                },
                onToggleFlag: {
                    appModel.persistentFocusedPane?.toggleFlag()
                },
                onSave: { appModel.saveWorkspaces() }
            )
            .environment(\.sidebarHasFocus, false)
            .environment(\.sidebarCursorPaneID, nil)
            .environment(\.modalIsOpen, appModel.modalState != .none)
        }
    }

    private func applyTheme(name: String, fallback: TerminalTheme? = nil) {
        let configContent = appModel.configFile.ghosttyConfigContent(themeOverride: name)
        if let resolved = GhosttyApp.shared.reloadConfig(ghosttyContent: configContent) {
            appModel.themeManager.setResolvedTheme(resolved)
        } else if let fallback {
            appModel.themeManager.setResolvedTheme(fallback)
        }
    }

    // MARK: - Traffic Light Positioning

    private static let trafficLightConstraintID = "hootty-traffic-light"
    private static let titleBarHeight: CGFloat = Layout.barHeight

    /// Reposition traffic light buttons to vertically center in the title bar.
    /// Uses Auto Layout constraints which persist across window move/resize/fullscreen.
    private static func repositionTrafficLights(in window: NSWindow) {
        guard let close = window.standardWindowButton(.closeButton),
              let minimize = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebarView = close.superview else { return }

        // Only apply once per window
        if titlebarView.constraints.contains(where: { $0.identifier == trafficLightConstraintID }) {
            return
        }

        // Expand the titlebar container to match our bar height
        if let titlebarContainer = titlebarView.superview {
            let heightConstraint = titlebarContainer.heightAnchor.constraint(equalToConstant: titleBarHeight)
            heightConstraint.identifier = trafficLightConstraintID
            heightConstraint.isActive = true
        }

        let buttonHeight = close.frame.height
        let offsetTop = (titleBarHeight - buttonHeight) / 2
        let leftInset: CGFloat = 12
        let buttonSpacing: CGFloat = 20

        for (index, button) in [close, minimize, zoom].enumerated() {
            button.translatesAutoresizingMaskIntoConstraints = false

            // Remove system autoresizing constraints on this button
            let existing = titlebarView.constraints.filter {
                $0.firstItem === button || $0.secondItem === button
            }
            NSLayoutConstraint.deactivate(existing)

            let top = button.topAnchor.constraint(equalTo: titlebarView.topAnchor, constant: offsetTop)
            top.identifier = trafficLightConstraintID
            let leading = button.leadingAnchor.constraint(
                equalTo: titlebarView.leadingAnchor,
                constant: leftInset + CGFloat(index) * buttonSpacing
            )
            leading.identifier = trafficLightConstraintID
            NSLayoutConstraint.activate([top, leading])
        }
    }
}
