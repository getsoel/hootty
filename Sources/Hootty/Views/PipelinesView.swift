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
            CapsulePickerView(
                options: [AppModel.PipelineMode.boards, .templates],
                selection: $appModel.pipelineMode,
                tokens: tokens,
                label: { $0 == .boards ? "Boards" : "Templates" }
            )
            .padding(.leading, Spacing.md)

            Spacer()

            if appModel.pipelineMode == .boards {
                repoFilterPicker
                    .padding(.trailing, Spacing.md)
            }
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
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
                appModel.makePipelineBoardView(
                    board: board,
                    tokens: tokens,
                    repoRoot: entry.repoRoot,
                    onClickClaimed: { sessionKey in
                        navigateToClaimedPane(sessionKey: sessionKey)
                    }
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMd)
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
