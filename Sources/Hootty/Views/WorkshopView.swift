import HoottyCore
import SwiftUI

struct WorkshopView: View {
    @Bindable var appModel: AppModel
    let tokens: DesignTokens
    @State private var editorText = ""
    @State private var loadedText = ""
    @State private var expandedChanges: Set<String> = []
    @State private var expandedRequirements: Set<String> = []
    @State private var archiveExpanded = false
    @State private var hoveredItem: String?

    private var theme: TerminalTheme {
        appModel.themeManager.theme
    }

    var body: some View {
        HStack(spacing: 0) {
            workshopSidebar
            Rectangle().fill(Color(tokens.border)).frame(width: 1)
            editorArea
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "s"), phases: .down) { press in
            guard press.modifiers == .command else { return .ignored }
            saveFile()
            return .handled
        }
    }

    // MARK: - Repo Resolution

    private var workshopRepoRoot: String? {
        if let root = appModel.selectedWorkspace?.focusedPane?.repoRoot {
            return root
        }
        for workspace in appModel.workspaces {
            for pane in workspace.allPanes {
                if let root = pane.repoRoot { return root }
            }
        }
        return appModel.workshopModel.statusByRepo.keys.sorted().first
    }

    // MARK: - Sidebar

    private var workshopSidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            sidebarContent
            Spacer(minLength: 0)
        }
        .frame(width: 220)
        .background(Color(tokens.surfaceLow))
    }

    private var sidebarHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))

            Text("Workshop")
                .font(.system(size: TypeScale.bodySize, weight: .medium))
                .foregroundStyle(Color(tokens.text))

            Spacer(minLength: 0)
        }
        .padding(.leading, Spacing.md)
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var sidebarContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let repoRoot = workshopRepoRoot,
                   let status = appModel.workshopModel.status(for: repoRoot) {
                    let active = status.changes.filter { !$0.isArchived }
                    let archived = status.changes.filter(\.isArchived)

                    ForEach(active) { change in
                        changeFolderRow(change)
                        if expandedChanges.contains(change.name) {
                            changeChildren(change, repoRoot: repoRoot)
                        }
                    }

                    if !archived.isEmpty {
                        archiveSectionHeader
                        if archiveExpanded {
                            ForEach(archived) { change in
                                changeFolderRow(change)
                                if expandedChanges.contains(change.name) {
                                    changeChildren(change, repoRoot: repoRoot)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { initializeExpanded() }
    }

    private func initializeExpanded() {
        guard let repoRoot = workshopRepoRoot,
              let status = appModel.workshopModel.status(for: repoRoot) else { return }
        expandedChanges = Set(status.changes.filter { !$0.isArchived }.map(\.name))
    }

    // MARK: - Change Folder Row (depth 0)

    private func changeFolderRow(_ change: WorkshopChange) -> some View {
        let isExpanded = expandedChanges.contains(change.name)
        let hoverKey = "change:\(change.name)"
        let isHovered = hoveredItem == hoverKey

        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(isExpanded ? tokens.text : tokens.textMuted))
                .frame(width: TreeLayout.columnWidth)

            Text(change.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isExpanded ? tokens.text : tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .background(
            Rectangle().fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredItem = hoverKey
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                if hoveredItem == hoverKey { hoveredItem = nil }
            }
        }
        .onTapGesture {
            if expandedChanges.contains(change.name) {
                expandedChanges.remove(change.name)
            } else {
                expandedChanges.insert(change.name)
            }
        }
    }

    // MARK: - Change Children

    private func changeChildren(_ change: WorkshopChange, repoRoot: String) -> some View {
        ForEach(change.artifacts) { artifact in
            if artifact.id == .requirements {
                requirementsSection(artifact: artifact, changeName: change.name, repoRoot: repoRoot)
            } else {
                artifactLeafRow(artifact, changeName: change.name, repoRoot: repoRoot)
            }
        }
    }

    // MARK: - Artifact Leaf Row (depth 1)

    private func artifactLeafRow(
        _ artifact: WorkshopArtifact,
        changeName: String,
        repoRoot: String
    ) -> some View {
        let filePath = appModel.workshopModel.artifactFilePath(
            repoRoot: repoRoot, changeName: changeName, artifactID: artifact.id
        )
        let isSelected = filePath != nil && filePath == appModel.workshopFilePath
        let hoverKey = "artifact:\(changeName):\(artifact.id.rawValue)"
        let isHovered = hoveredItem == hoverKey
        let isClickable = filePath != nil
        let isStale = appModel.workshopModel.isStale(changeName: changeName, artifactID: artifact.id)

        return HStack(spacing: 6) {
            artifactStatusIcon(artifact.state, isStale: isStale)
                .frame(width: TreeLayout.columnWidth)

            Text(artifact.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(artifactTextColor(artifact.state, isSelected: isSelected))
                .lineLimit(1)

            if isStale {
                Text("edited")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.statusWarning))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + TreeLayout.columnWidth)
        .background(
            Rectangle().fill(
                isSelected ? Color(tokens.elementSelected)
                    : isHovered && isClickable ? Color(tokens.elementHover)
                    : Color.clear
            )
        )
        .background(TreeLinesBackground(depth: 1, tokens: tokens))
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredItem = hoverKey
                if isClickable {
                    DispatchQueue.main.async { NSCursor.pointingHand.set() }
                }
            case .ended:
                if hoveredItem == hoverKey { hoveredItem = nil }
            }
        }
        .onTapGesture {
            guard let filePath else { return }
            appModel.workshopFilePath = filePath
        }
    }

    // MARK: - Requirements Section (depth 1 folder + depth 2 children)

    @ViewBuilder
    private func requirementsSection(artifact: WorkshopArtifact, changeName: String, repoRoot: String) -> some View {
        let reqFiles = appModel.workshopModel.requirementFiles(repoRoot: repoRoot, changeName: changeName)

        if reqFiles.isEmpty {
            artifactLeafRow(artifact, changeName: changeName, repoRoot: repoRoot)
        } else {
            requirementsFolderRow(artifact: artifact, changeName: changeName, reqCount: reqFiles.count)

            if expandedRequirements.contains(changeName) {
                ForEach(reqFiles) { req in
                    requirementFileRow(req: req)
                }
            }
        }
    }

    private func requirementsFolderRow(artifact: WorkshopArtifact, changeName: String, reqCount: Int) -> some View {
        let isExpanded = expandedRequirements.contains(changeName)
        let hoverKey = "requirements:\(changeName)"
        let isHovered = hoveredItem == hoverKey
        let isStale = appModel.workshopModel.isStale(changeName: changeName, artifactID: .requirements)

        return HStack(spacing: 6) {
            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(requirementsFolderColor(artifact.state, isStale: isStale, isExpanded: isExpanded))
                .frame(width: TreeLayout.columnWidth)

            Text("Requirements")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(requirementsFolderColor(artifact.state, isStale: isStale, isExpanded: isExpanded))
                .lineLimit(1)

            Text("\(reqCount)")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))

            if isStale {
                Text("edited")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.statusWarning))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + TreeLayout.columnWidth)
        .background(
            Rectangle().fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .background(TreeLinesBackground(depth: 1, tokens: tokens))
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredItem = hoverKey
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                if hoveredItem == hoverKey { hoveredItem = nil }
            }
        }
        .onTapGesture {
            if expandedRequirements.contains(changeName) {
                expandedRequirements.remove(changeName)
            } else {
                expandedRequirements.insert(changeName)
            }
        }
    }

    private func requirementFileRow(req: WorkshopModel.RequirementFile) -> some View {
        let isSelected = req.path == appModel.workshopFilePath
        let hoverKey = "req:\(req.path)"
        let isHovered = hoveredItem == hoverKey

        return HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .frame(width: TreeLayout.columnWidth)

            Text(req.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + 2 * TreeLayout.columnWidth)
        .background(
            Rectangle().fill(
                isSelected ? Color(tokens.elementSelected)
                    : isHovered ? Color(tokens.elementHover)
                    : Color.clear
            )
        )
        .background(TreeLinesBackground(depth: 2, tokens: tokens))
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredItem = hoverKey
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                if hoveredItem == hoverKey { hoveredItem = nil }
            }
        }
        .onTapGesture {
            appModel.workshopFilePath = req.path
        }
    }

    // MARK: - Archive Section

    private var archiveSectionHeader: some View {
        let hoverKey = "archive-header"
        let isHovered = hoveredItem == hoverKey

        return HStack(spacing: 6) {
            Image(systemName: archiveExpanded ? "archivebox.fill" : "archivebox")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(archiveExpanded ? 1 : 0.5))
                .frame(width: TreeLayout.columnWidth)

            Text("Archive")
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textMuted).opacity(archiveExpanded ? 1 : 0.5))
                .textCase(.uppercase)

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.smd)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .background(
            Rectangle().fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredItem = hoverKey
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                if hoveredItem == hoverKey { hoveredItem = nil }
            }
        }
        .onTapGesture {
            archiveExpanded.toggle()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func artifactStatusIcon(_ state: WorkshopArtifactState, isStale: Bool) -> some View {
        if isStale {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.statusWarning))
        } else {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.statusSuccess).opacity(0.6))
            case .ready:
                Image(systemName: "circle")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textAccent))
            case .blocked:
                Image(systemName: "circle")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.3))
            }
        }
    }

    private func artifactTextColor(_ state: WorkshopArtifactState, isSelected: Bool) -> Color {
        if isSelected { return Color(tokens.text) }
        switch state {
        case .done: return Color(tokens.textMuted)
        case .ready: return Color(tokens.textAccent)
        case .blocked: return Color(tokens.textMuted).opacity(0.3)
        }
    }

    private func requirementsFolderColor(_ state: WorkshopArtifactState, isStale: Bool, isExpanded: Bool) -> Color {
        if isStale { return Color(tokens.statusWarning) }
        if isExpanded { return Color(tokens.text) }
        switch state {
        case .done: return Color(tokens.textMuted)
        case .ready: return Color(tokens.textAccent)
        case .blocked: return Color(tokens.textMuted).opacity(0.3)
        }
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        VStack(spacing: 0) {
            if let filePath = appModel.workshopFilePath {
                editorBar(filePath: filePath)
                MarkdownEditorView(text: $editorText, theme: theme)
                    .onAppear { loadFile(filePath) }
                    .onChange(of: appModel.workshopFilePath) { _, newPath in
                        if let newPath { loadFile(newPath) }
                    }
            } else {
                emptyState
            }
        }
        .background(Color(tokens.surface))
    }

    private func editorBar(filePath: String) -> some View {
        HStack(spacing: 0) {
            if appModel.workshopSourcePaneID != nil {
                BarIconButton(
                    systemImage: "chevron.left",
                    tokens: tokens,
                    accessibilityLabel: "Back to pane",
                    help: "Return to source pane",
                    action: navigateBack
                )
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted))

                Text((filePath as NSString).lastPathComponent)
                    .font(.system(size: TypeScale.smallSize, weight: .medium))
                    .foregroundStyle(Color(tokens.text))
                    .lineLimit(1)

                if editorText != loadedText {
                    Circle()
                        .fill(Color(tokens.textMuted))
                        .frame(width: 6, height: 6)
                }

                if let range = filePath.range(of: "workshop/") {
                    Text(String(filePath[range.lowerBound...].dropFirst("workshop/".count)))
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                        .lineLimit(1)
                }
            }
            .padding(.leading, Spacing.md)

            Spacer(minLength: 0)

            if editorText != loadedText {
                BarIconButton(
                    systemImage: "square.and.arrow.down",
                    tokens: tokens,
                    accessibilityLabel: "Save",
                    help: "Save file (⌘S)",
                    iconColor: tokens.textAccent,
                    action: saveFile
                )
            }
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private func navigateBack() {
        if let paneID = appModel.workshopSourcePaneID,
           let (workspace, _) = appModel.findPane(id: paneID) {
            appModel.selectedWorkspaceID = workspace.id
            workspace.focusPane(id: paneID)
        }
        appModel.workshopSourcePaneID = nil
        appModel.appMode = .workspaces
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: TypeScale.iconSize * 2))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.4))
            Text("Select an artifact to edit")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File I/O

    private func loadFile(_ path: String) {
        let content: String = if let data = FileManager.default.contents(atPath: path),
                                 let text = String(data: data, encoding: .utf8) {
            text
        } else {
            ""
        }
        loadedText = content
        editorText = content
    }

    private func saveFile() {
        guard let filePath = appModel.workshopFilePath else { return }
        guard editorText != loadedText else { return }
        let textToSave = editorText
        try? textToSave.write(toFile: filePath, atomically: true, encoding: .utf8)
        loadedText = textToSave

        if let ctx = appModel.workshopModel.resolveArtifactContext(filePath: filePath) {
            appModel.workshopModel.markArtifactStale(
                repoRoot: ctx.repoRoot, changeName: ctx.changeName, artifactID: ctx.artifactID
            )
        }
    }
}
