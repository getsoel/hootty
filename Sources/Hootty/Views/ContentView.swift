import HoottyCore
import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppModel
    var commandRegistry: CommandRegistry
    @GestureState private var dragOffset: CGFloat = 0
    @State private var prePickerTheme: (name: String, theme: TerminalTheme)?
    @State private var sidebarCursorPaneID: UUID?
    @State private var selectedPipelineName: String?
    @State private var showCreatePipeline = false
    @State private var newPipelineName: String = ""
    @State private var selectedTemplateName: String = "review"
    @State private var availableTemplates: [(name: String, stages: [PipelineStageDef])] = []
    @State private var showDeleteConfirmation = false
    @State private var pipelineToDelete: String?

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
        .onChange(of: appModel.modalState) { _, state in
            if state == .themePicker {
                appModel.themeManager.themeCatalog.loadPreviews()
                prePickerTheme = (
                    name: appModel.themeManager.selectedThemeName,
                    theme: appModel.themeManager.theme
                )
            }
        }
        .onChange(of: appModel.pipelinesEnabled) { _, enabled in
            if !enabled {
                appModel.appMode = .workspaces
                appModel.detailMode = .terminals
            }
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(
            workspaces: appModel.workspaces,
            selectedWorkspaceID: $appModel.selectedWorkspaceID,
            tokens: tokens,
            detailMode: $appModel.detailMode,
            onAddWorkspace: {
                let workspace = appModel.addWorkspace()
                appModel.selectedWorkspaceID = workspace.id
            },
            onRemoveWorkspace: { id in
                if let workspace = appModel.workspaces.first(where: { $0.id == id }) {
                    for pane in workspace.allPanes {
                        appModel.macroRunner.remove(paneID: pane.id)
                    }
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
                    appModel.macroRunner.remove(paneID: paneID)
                    GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                    workspace.removePane(id: paneID)
                    appModel.saveWorkspaces()
                }
            },
            onCreateWorktree: { workspaceID, repoRoot, branch in
                guard let workspace = appModel.workspaces.first(where: { $0.id == workspaceID }),
                      let worktreePath = GitWorktreeManager.resolveWorktreePath(repoPath: repoRoot, branch: branch) else { return }
                let parentSurface = GhosttyApp.shared.focusedSurface
                if let newPane = workspace.splitFocusedPane(direction: .horizontal, workingDirectory: worktreePath) {
                    if let parentSurface {
                        GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                    }
                    appModel.saveWorkspaces()
                }
            },
            onSave: { appModel.saveWorkspaces() },
            sidebarHasFocus: $appModel.sidebarHasFocus,
            sidebarCursorPaneID: $sidebarCursorPaneID,
            sidebarWidth: effectiveSidebarWidth,
            showWorktreeActions: $appModel.showWorktreeActions,
            moduleFlags: appModel.moduleFlags,
            pipelineAttentionCount: appModel.pipelinesEnabled ? currentPipelineAttentionCount : 0
        )
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Leave space for traffic lights
            Color.clear.frame(width: 78)

            appModePicker

            Spacer()
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var appModePicker: some View {
        if appModel.pipelinesEnabled {
            CapsulePickerView(
                options: [AppModel.AppMode.workspaces, .pipelines],
                selection: $appModel.appMode,
                tokens: tokens,
                label: { $0 == .workspaces ? "Workspaces" : "Pipelines" }
            )
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if appModel.pipelinesEnabled {
            switch appModel.appMode {
            case .workspaces:
                workspacesContent
            case .pipelines:
                PipelinesView(appModel: appModel, tokens: tokens)
            }
        } else {
            workspacesContent
        }
    }

    private var workspacesContent: some View {
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
    }

    @ViewBuilder
    private var detailView: some View {
        if let workspace = selectedWorkspace {
            if appModel.pipelinesEnabled {
                switch appModel.detailMode {
                case .terminals:
                    terminalsDetail(workspace: workspace)
                case .board:
                    boardDetail(workspace: workspace)
                }
            } else {
                terminalsDetail(workspace: workspace)
            }
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
            pipelineModel: appModel.pipelineModel,
            macroRunner: appModel.macroRunner,
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
                appModel.macroRunner.remove(paneID: paneID)
                GhosttyApp.shared.removeCachedSurfaceView(for: paneID)
                workspace.removePane(id: paneID)
                appModel.saveWorkspaces()
            },
            onSwapPanes: { sourceID, targetID in
                workspace.swapPanes(sourceID, targetID)
                appModel.saveWorkspaces()
            },
            onSave: { appModel.saveWorkspaces() },
            onSwitchToBoard: appModel.pipelinesEnabled ? { pipelineName in
                selectedPipelineName = pipelineName
                appModel.detailMode = .board
            } : nil,
            onPipelineRefresh: appModel.pipelinesEnabled ? { repoRoot in
                appModel.refreshPipeline(repoRoot: repoRoot)
            } : nil,
            moduleFlags: appModel.moduleFlags
        )
        .environment(\.sidebarHasFocus, appModel.sidebarHasFocus)
        .environment(\.sidebarCursorPaneID, sidebarCursorPaneID)
        .environment(\.modalIsOpen, appModel.modalState != .none)
        .id(workspace.id)
    }

    @ViewBuilder
    private func boardDetail(workspace: Workspace) -> some View {
        let boards = currentBoardData(workspace: workspace)
        let repoRoot = currentRepoRoot(workspace: workspace)
        if boards.isEmpty {
            boardEmptyState(workspace: workspace)
        } else {
            VStack(spacing: 0) {
                // Pipeline selector (only if multiple pipelines)
                if boards.count > 1 {
                    pipelineSelector(boards: boards, repoRoot: repoRoot)
                }

                // Selected board
                let activeBoard = resolveActiveBoard(boards: boards)
                if let board = activeBoard, let repoRoot {
                    appModel.makePipelineBoardView(
                        board: board,
                        tokens: tokens,
                        repoRoot: repoRoot,
                        onClickClaimed: { sessionKey in
                            navigateToClaimedPane(sessionKey: sessionKey, workspace: workspace)
                        },
                        onClaimInWorktree: { slug in
                            claimInWorktree(slug: slug, repoRoot: repoRoot, workspace: workspace)
                        }
                    )
                    .task(id: appModel.pipelineModel.highlightedJobSlug) {
                        guard appModel.pipelineModel.highlightedJobSlug != nil else { return }
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if !Task.isCancelled {
                            appModel.pipelineModel.highlightedJobSlug = nil
                        }
                    }
                }
            }
            .background(Color(tokens.background))
        }
    }

    // MARK: - Board Empty State

    private func boardEmptyState(workspace: Workspace) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 32))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.4))
            Text("No pipelines")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
            Text("Create a pipeline to organize work into stages")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.6))

            if let repoRoot = currentRepoRoot(workspace: workspace) {
                Button("Create Pipeline") {
                    newPipelineName = "default"
                    selectedTemplateName = "review"
                    availableTemplates = loadGlobalTemplates()
                    showCreatePipeline = true
                }
                .buttonStyle(.plain)
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textAccent))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Layout.cornerRadiusMd)
                        .fill(Color(tokens.textAccent).opacity(0.1))
                )
                .sheet(isPresented: $showCreatePipeline) {
                    createPipelineSheet(repoRoot: repoRoot)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createPipelineSheet(repoRoot: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Create Pipeline")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(tokens.text))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Name")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.textMuted))
                TextField("Pipeline name", text: $newPipelineName)
                    .textFieldStyle(.plain)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.text))
                    .padding(Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm).fill(Color(tokens.surfaceHighlight).opacity(0.3)))
                    .overlay(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm).stroke(Color(tokens.border), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Template")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.textMuted))
                ForEach(availableTemplates, id: \.name) { template in
                    templateRow(name: template.name, stages: template.stages)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { showCreatePipeline = false }
                    .buttonStyle(.plain)
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.textMuted))

                Button("Create") {
                    let name = newPipelineName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
                    let stages = availableTemplates.first(where: { $0.name == selectedTemplateName })?.stages
                        ?? PipelineTemplate.review.stages
                    if appModel.pipelineModel.createPipeline(repoRoot: repoRoot, pipelineName: slug, displayName: name, stages: stages) {
                        appModel.refreshPipeline(repoRoot: repoRoot)
                        selectedPipelineName = slug
                    }
                    showCreatePipeline = false
                }
                .buttonStyle(.plain)
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textAccent))
            }
        }
        .padding(Spacing.xl)
        .frame(width: 360)
        .background(Color(tokens.surface))
    }

    private func templateRow(name: String, stages: [PipelineStageDef]) -> some View {
        let isSelected = selectedTemplateName == name
        let displayName = name.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        return Button {
            selectedTemplateName = name
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(isSelected ? tokens.textAccent : tokens.textMuted))

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: TypeScale.captionSize, weight: .medium))
                        .foregroundStyle(Color(tokens.text))
                    Text(stages.map(\.name).joined(separator: " → "))
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                }
                Spacer()
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                    .fill(isSelected ? Color(tokens.elementSelected) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pipelineSelector(boards: [PipelineBoardData], repoRoot: String?) -> some View {
        HStack(spacing: 2) {
            ForEach(boards) { board in
                let isActive = resolveActiveBoard(boards: boards)?.pipelineName == board.pipelineName
                Button {
                    selectedPipelineName = board.pipelineName
                } label: {
                    pipelineSelectorLabel(board: board, isActive: isActive)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete Pipeline", role: .destructive) {
                        pipelineToDelete = board.pipelineName
                        showDeleteConfirmation = true
                    }
                }
            }

            if let repoRoot {
                pipelineAddButton(repoRoot: repoRoot)
            }
        }
        .padding(Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(tokens.surface))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
        .alert("Delete Pipeline?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { pipelineToDelete = nil }
            Button("Delete", role: .destructive) {
                if let name = pipelineToDelete, let repoRoot {
                    if appModel.pipelineModel.deletePipeline(repoRoot: repoRoot, pipelineName: name) {
                        if selectedPipelineName == name { selectedPipelineName = nil }
                        appModel.refreshPipeline(repoRoot: repoRoot)
                    }
                }
                pipelineToDelete = nil
            }
        } message: {
            Text("This will permanently delete the pipeline and all its jobs.")
        }
    }

    private func pipelineSelectorLabel(board: PipelineBoardData, isActive: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(board.displayName)
                .font(.system(size: TypeScale.captionSize, weight: isActive ? .medium : .regular))
                .foregroundStyle(Color(isActive ? tokens.text : tokens.textMuted))

            let activeCount = board.jobs.filter { $0.status == .active || $0.status == .interrupted }.count
            if activeCount > 0 {
                Text("\(activeCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(tokens.textAccent))
                    .padding(.horizontal, Spacing.xs + 1)
                    .background(
                        Capsule().fill(Color(tokens.textAccent).opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(isActive ? Color(tokens.elementSelected) : Color.clear)
        )
    }

    private func pipelineAddButton(repoRoot: String) -> some View {
        Button {
            newPipelineName = ""
            selectedTemplateName = "review"
            availableTemplates = loadGlobalTemplates()
            showCreatePipeline = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Create new pipeline")
        .sheet(isPresented: $showCreatePipeline) {
            createPipelineSheet(repoRoot: repoRoot)
        }
    }

    private func resolveActiveBoard(boards: [PipelineBoardData]) -> PipelineBoardData? {
        if let name = selectedPipelineName,
           let board = boards.first(where: { $0.pipelineName == name }) {
            return board
        }
        return boards.first
    }

    private var currentPipelineAttentionCount: Int {
        guard let workspace = selectedWorkspace,
              let repoRoot = currentRepoRoot(workspace: workspace) else { return 0 }
        return appModel.pipelineModel.attentionCount(for: repoRoot)
    }

    private func currentBoardData(workspace: Workspace) -> [PipelineBoardData] {
        guard let repoRoot = currentRepoRoot(workspace: workspace) else { return [] }
        return appModel.pipelineModel.boardData(for: repoRoot)
    }

    private func currentRepoRoot(workspace: Workspace) -> String? {
        workspace.focusedPane?.repoRoot
    }

    private func loadGlobalTemplates() -> [(name: String, stages: [PipelineStageDef])] {
        let store = TemplateStore(rootPath: TemplateStore.defaultDirectory)
        store.seedDefaults()
        return store.listTemplates().compactMap { name in
            guard let config = try? store.loadTemplate(name: name) else { return nil }
            return (name: name, stages: config.stages)
        }
    }

    private func navigateToClaimedPane(sessionKey: String, workspace: Workspace) {
        // Find the pane that has this session key
        for pane in workspace.allPanes {
            let sessionIDs = [pane.id.uuidString] + (pane.claudeSessionID.map { [$0] } ?? [])
            if sessionIDs.contains(sessionKey) {
                appModel.detailMode = .terminals
                workspace.focusPane(id: pane.id)
                return
            }
        }
    }

    private func claimInWorktree(slug: String, repoRoot: String, workspace: Workspace) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["hootty", "pipeline", "claim", "--job", slug, "--worktree"]
            process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            guard (try? process.run()) != nil else { return }

            // Read stdout before waitUntilExit to avoid pipe buffer deadlock
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: outputData, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                let worktreePath = output.components(separatedBy: .newlines)
                    .first { $0.contains("Working directory:") }
                    .flatMap { line in
                        let parts = line.components(separatedBy: ":")
                        return parts.count > 1 ? parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces) : nil
                    }
                let targetDir = worktreePath ?? repoRoot

                let parentSurface = GhosttyApp.shared.focusedSurface
                if let newPane = workspace.splitFocusedPane(direction: .horizontal, workingDirectory: targetDir) {
                    if let parentSurface {
                        GhosttyApp.shared.registerParentSurface(newPane.id, surface: parentSurface)
                    }
                    appModel.detailMode = .terminals
                    appModel.saveWorkspaces()
                }
                appModel.refreshPipeline(repoRoot: repoRoot)
            }
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
