import HoottyCore
import SwiftUI

extension AppModel {
    /// Constructs a PipelineBoardView with all standard pipeline model callbacks wired up.
    /// `onClickClaimed` and `onClaimInWorktree` vary by context so are passed in.
    func makePipelineBoardView(
        board: PipelineBoardData,
        tokens: DesignTokens,
        repoRoot: String,
        onClickClaimed: @escaping (String) -> Void,
        onClaimInWorktree: ((String) -> Void)? = nil
    ) -> PipelineBoardView {
        PipelineBoardView(
            boardData: board,
            tokens: tokens,
            highlightedJobSlug: pipelineModel.highlightedJobSlug,
            onTogglePause: {
                if self.pipelineModel.togglePause(repoRoot: repoRoot, pipelineName: board.pipelineName) {
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onMoveJob: { slug, from, to in
                if self.pipelineModel.moveJob(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug, fromStageIndex: from, toStageIndex: to, stages: board.stages) {
                    _ = self.pipelineModel.appendLogEntry(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug, message: "Moved to \(board.stages[safe: to]?.name ?? "unknown")")
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onAddJob: { title, stageIndex in
                if let slug = self.pipelineModel.addJob(repoRoot: repoRoot, pipelineName: board.pipelineName, title: title, stages: board.stages, toStageIndex: stageIndex) {
                    _ = self.pipelineModel.appendLogEntry(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug, message: "Created")
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onRemoveJob: { slug in
                _ = self.pipelineModel.appendLogEntry(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug, message: "Removed")
                if self.pipelineModel.removeJob(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug) {
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onClickClaimed: onClickClaimed,
            onLoadJobBody: { slug in
                self.pipelineModel.readJobBody(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug)
            },
            onLoadFullContent: { slug in
                self.pipelineModel.readFullJobContent(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug)
            },
            onUpdateTitle: { slug, newTitle in
                if self.pipelineModel.updateJobTitle(repoRoot: repoRoot, pipelineName: board.pipelineName, jobSlug: slug, newTitle: newTitle) {
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onAddStage: { name, type, afterIndex in
                if self.pipelineModel.addStage(repoRoot: repoRoot, pipelineName: board.pipelineName, stageName: name, type: type, afterIndex: afterIndex) {
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onRemoveStage: { stageIndex in
                if self.pipelineModel.removeStage(repoRoot: repoRoot, pipelineName: board.pipelineName, stageIndex: stageIndex) {
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onChangeStageType: { stageIndex, newType in
                if self.pipelineModel.changeStageType(repoRoot: repoRoot, pipelineName: board.pipelineName, stageIndex: stageIndex, newType: newType) {
                    self.refreshPipeline(repoRoot: repoRoot)
                }
            },
            onClaimInWorktree: onClaimInWorktree,
            onArchive: {
                self.archivePipeline(name: board.pipelineName, repoRoot: repoRoot)
            }
        )
    }
}
