import HoottyCore
import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppModel
    var commandRegistry: CommandRegistry
    /// Called after pane/workspace removal to clean up file watchers for a repo root.
    var onCleanupRepoWatchers: ((String) -> Void)?
    @GestureState private var dragOffset: CGFloat = 0
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
            onToggleSidebar: { appModel.toggleSidebar() },
            pinnedWorkspaceID: appModel.pinnedWorkspaceID,
            onTogglePinWorkspace: { appModel.togglePinWorkspace(id: $0) }
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
            sidebarHasFocus: $appModel.sidebarHasFocus,
            sidebarCursorTarget: $sidebarCursorTarget,
            pinnedWorkspaceID: appModel.pinnedWorkspaceID
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

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Leave space for traffic lights
            Color.clear.frame(width: 78)

            profileMenu

            Spacer()

            if memoryMonitor.memoryMB > 0 {
                Button {
                    appModel.modalState = .memoryLog
                } label: {
                    TitlebarChip(tokens: tokens) {
                        Text("\(memoryMonitor.memoryMB) MB")
                            .font(.system(size: TypeScale.bodySize).monospacedDigit())
                    }
                }
                .buttonStyle(.plain)
                .help("Activity Monitor")
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

    private var profileMenu: some View {
        Menu {
            Picker("Active Profile", selection: profileSelectionBinding) {
                ForEach(appModel.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button(AppCommand.newProfile.title) {
                commandRegistry.execute(.newProfile)
            }
            Button(AppCommand.renameCurrentProfile.title) {
                commandRegistry.execute(.renameCurrentProfile)
            }
            Button(AppCommand.deleteCurrentProfile.title) {
                commandRegistry.execute(.deleteCurrentProfile)
            }
            .disabled(appModel.profiles.count <= 1)
        } label: {
            TitlebarChip(tokens: tokens) {
                Text(appModel.activeProfile?.name ?? "")
                    .font(.system(size: TypeScale.bodySize))
            }
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Profile")
    }

    private var profileSelectionBinding: Binding<UUID> {
        Binding(
            get: { appModel.activeProfileID },
            set: { newID in
                guard newID != appModel.activeProfileID else { return }
                // Route through the palette's switch-profile commands so that
                // supplementary command refresh (used by the command palette) stays in sync.
                if let cmd = commandRegistry.paletteCommands.first(where: {
                    $0.id == "switch-profile-\(newID.uuidString)"
                }) {
                    cmd.action()
                } else {
                    appModel.switchProfile(to: newID)
                }
            }
        )
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
            let contentX = sidebarW + dividerW
            let fullWidth = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
            let contentW = max(0, fullWidth - contentX)
            let contentH = geometry.size.height

            ZStack(alignment: .topLeading) {
                // Sidebar
                if appModel.sidebarMode != .hidden {
                    sidebarContent
                        .frame(width: sidebarW, height: contentH)

                    // Visible 1px divider line
                    Rectangle()
                        .fill(Color(tokens.border))
                        .frame(width: 1, height: contentH)
                        .offset(x: sidebarW)

                    // Invisible wide drag handle overlaying the divider (full mode only)
                    if appModel.sidebarMode == .full {
                        sidebarDragHandle(sidebarW: sidebarW, contentH: contentH)
                    }
                }

                // Detail area
                detailView
                    .frame(width: contentW, height: contentH)
                    .offset(x: contentX)
            }
            .frame(width: fullWidth, alignment: .topLeading)
            .clipped()
        }
    }

    private func sidebarDragHandle(sidebarW: CGFloat, contentH: CGFloat) -> some View {
        Color.clear
            .frame(width: 16, height: contentH)
            .contentShape(Rectangle())
            .offset(x: sidebarW - 7.5)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    DispatchQueue.main.async { NSCursor.resizeLeftRight.set() }
                case .ended:
                    DispatchQueue.main.async { NSCursor.arrow.set() }
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
            focusedPaneID: workspace.focusedPaneID,
            tokens: tokens,
            isInSplit: false,
            onFocusPane: { paneID in
                appModel.sidebarHasFocus = false
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

/// Styled chip used for interactive elements in the titlebar (profile menu, activity monitor).
/// Applies consistent padding, rounded background, hover state, and pointer cursor.
private struct TitlebarChip<Content: View>: View {
    let tokens: DesignTokens
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false

    var body: some View {
        content()
            .foregroundStyle(Color(tokens.textMuted))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                    .fill(Color(isHovered ? tokens.elementSelected : tokens.elementHover))
            )
            .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                    DispatchQueue.main.async { NSCursor.pointingHand.set() }
                case .ended:
                    isHovered = false
                @unknown default:
                    break
                }
            }
    }
}
