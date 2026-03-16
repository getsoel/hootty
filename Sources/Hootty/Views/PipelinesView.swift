import HoottyCore
import SwiftUI

struct PipelinesView: View {
    @Bindable var appModel: AppModel
    let tokens: DesignTokens

    @State private var repoFilter: String?

    var body: some View {
        VStack(spacing: 0) {
            pipelineModePicker
            modeContent
        }
        .background(Color(tokens.background))
    }

    // MARK: - Mode Picker

    private var pipelineModePicker: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                pipelineModeLabel(mode: .boards, title: "Boards")
                pipelineModeLabel(mode: .templates, title: "Templates")
            }
            .padding(2)
            .background(
                Capsule()
                    .fill(Color(tokens.surfaceHighlight).opacity(0.3))
            )
            .padding(.leading, Spacing.md)

            Spacer()

            if appModel.pipelineMode == .boards {
                repoFilterPicker
                    .padding(.trailing, Spacing.md)
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private func pipelineModeLabel(mode: AppModel.PipelineMode, title: String) -> some View {
        let isActive = appModel.pipelineMode == mode
        return Text(title)
            .font(.system(size: TypeScale.captionSize, weight: isActive ? .medium : .regular))
            .foregroundStyle(Color(isActive ? tokens.text : tokens.textMuted))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 1)
            .background(
                Capsule()
                    .fill(isActive ? Color(tokens.elementSelected) : Color.clear)
            )
            .contentShape(Capsule())
            .onTapGesture { appModel.pipelineMode = mode }
    }

    private var repoFilterPicker: some View {
        let repos = allRepoRoots
        return Group {
            if repos.count > 1 {
                HStack(spacing: Spacing.sm) {
                    Text("Repo:")
                        .font(.system(size: TypeScale.captionSize))
                        .foregroundStyle(Color(tokens.textMuted))

                    Picker("", selection: $repoFilter) {
                        Text("All").tag(nil as String?)
                        ForEach(repos, id: \.self) { repo in
                            Text(repoDisplayName(repo))
                                .tag(repo as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }
            }
        }
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch appModel.pipelineMode {
        case .boards:
            boardsContent
        case .templates:
            TemplateEditorView(tokens: tokens)
        }
    }

    // MARK: - Boards Content

    @ViewBuilder
    private var boardsContent: some View {
        let entries = filteredBoardEntries
        if entries.isEmpty {
            boardsEmptyState
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    ForEach(entries, id: \.id) { entry in
                        boardSection(entry: entry)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private var boardsEmptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 32))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.4))
            Text("No active pipelines")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
            Text("Pipelines appear here when repos have .hootty/pipeline/ configured")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func boardSection(entry: RepoBoardEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Repo header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted))
                Text(repoDisplayName(entry.repoRoot))
                    .font(.system(size: TypeScale.captionSize, weight: .medium))
                    .foregroundStyle(Color(tokens.text))

                Spacer()
            }

            // Pipeline boards for this repo
            ForEach(entry.boards) { board in
                PipelineBoardView(
                    boardData: board,
                    tokens: tokens,
                    highlightedJobSlug: appModel.pipelineModel.highlightedJobSlug,
                    onTogglePause: {
                        if appModel.pipelineModel.togglePause(repoRoot: entry.repoRoot, pipelineName: board.pipelineName) {
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onMoveJob: { slug, from, to in
                        if appModel.pipelineModel.moveJob(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug, fromStageIndex: from, toStageIndex: to, stages: board.stages) {
                            _ = appModel.pipelineModel.appendLogEntry(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug, message: "Moved to \(board.stages[safe: to]?.name ?? "unknown")")
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onAddJob: { title, stageIndex in
                        if let slug = appModel.pipelineModel.addJob(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, title: title, stages: board.stages, toStageIndex: stageIndex) {
                            _ = appModel.pipelineModel.appendLogEntry(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug, message: "Created")
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onRemoveJob: { slug in
                        _ = appModel.pipelineModel.appendLogEntry(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug, message: "Removed")
                        if appModel.pipelineModel.removeJob(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug) {
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onClickClaimed: { sessionKey in
                        navigateToClaimedPane(sessionKey: sessionKey)
                    },
                    onLoadJobBody: { slug in
                        appModel.pipelineModel.readJobBody(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug)
                    },
                    onLoadFullContent: { slug in
                        appModel.pipelineModel.readFullJobContent(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug)
                    },
                    onUpdateTitle: { slug, newTitle in
                        if appModel.pipelineModel.updateJobTitle(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, jobSlug: slug, newTitle: newTitle) {
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onAddStage: { name, type, afterIndex in
                        if appModel.pipelineModel.addStage(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, stageName: name, type: type, afterIndex: afterIndex) {
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onRemoveStage: { stageIndex in
                        if appModel.pipelineModel.removeStage(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, stageIndex: stageIndex) {
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onChangeStageType: { stageIndex, newType in
                        if appModel.pipelineModel.changeStageType(repoRoot: entry.repoRoot, pipelineName: board.pipelineName, stageIndex: stageIndex, newType: newType) {
                            appModel.refreshPipeline(repoRoot: entry.repoRoot)
                        }
                    },
                    onArchive: {
                        appModel.archivePipeline(name: board.pipelineName, repoRoot: entry.repoRoot)
                    }
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(tokens.surface))
        )
    }

    // MARK: - Data

    private var allRepoRoots: [String] {
        Array(appModel.pipelineModel.boardDataByRepo.keys).sorted()
    }

    private var filteredBoardEntries: [RepoBoardEntry] {
        let repos: [String] = if let filter = repoFilter {
            [filter]
        } else {
            allRepoRoots
        }

        return repos.compactMap { repo in
            let boards = appModel.pipelineModel.boardData(for: repo)
            guard !boards.isEmpty else { return nil }
            return RepoBoardEntry(repoRoot: repo, boards: boards)
        }
    }

    private func repoDisplayName(_ repoRoot: String) -> String {
        (repoRoot as NSString).lastPathComponent
    }

    // MARK: - Actions

    private func navigateToClaimedPane(sessionKey: String) {
        for workspace in appModel.workspaces {
            for pane in workspace.allPanes {
                let sessionIDs = [pane.id.uuidString] + (pane.claudeSessionID.map { [$0] } ?? [])
                if sessionIDs.contains(sessionKey) {
                    appModel.appMode = .workspaces
                    appModel.detailMode = .terminals
                    appModel.selectedWorkspaceID = workspace.id
                    workspace.focusPane(id: pane.id)
                    return
                }
            }
        }
    }
}

// MARK: - Data Types

private struct RepoBoardEntry: Identifiable {
    let repoRoot: String
    let boards: [PipelineBoardData]

    var id: String {
        repoRoot
    }
}
