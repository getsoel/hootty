import Foundation

/// Observable model holding resolved pipeline claim info for each pane.
/// Updated by the PipelineWatcher whenever `.hootty/pipeline/.state.json` changes.
@MainActor
@Observable
public final class PipelineModel {
    /// Resolved claim info per pane ID. Nil means no active claim for that pane.
    public private(set) var claimsByPane: [UUID: PipelineClaimInfo] = [:]

    /// Full board data per repo root, keyed by repo root path.
    public private(set) var boardDataByRepo: [String: [PipelineBoardData]] = [:]

    /// Set of repo roots known to have `.hootty/pipeline/` directories.
    public private(set) var watchedRepoRoots: Set<String> = []

    /// Callback fired when a pane's claim status transitions to interrupted.
    public var onPaneInterrupted: ((UUID) -> Void)?

    /// The job slug to highlight on the board (set during cross-view navigation, cleared after display).
    public var highlightedJobSlug: String?

    public init() {}

    /// Get the claim info for a specific pane, if any.
    public func claimInfo(for paneID: UUID) -> PipelineClaimInfo? {
        claimsByPane[paneID]
    }

    /// Total count of jobs needing human attention across all pipelines in a repo.
    public func attentionCount(for repoRoot: String) -> Int {
        boardData(for: repoRoot).reduce(0) { $0 + $1.jobsNeedingAttention }
    }

    /// Get board data for a specific repo root.
    public func boardData(for repoRoot: String) -> [PipelineBoardData] {
        boardDataByRepo[repoRoot] ?? []
    }

    /// Register a repo root as having a `.hootty/pipeline/` directory.
    /// Returns true if this is a newly discovered root (caller should start watching).
    @discardableResult
    public func registerRepoRoot(_ repoRoot: String) -> Bool {
        watchedRepoRoots.insert(repoRoot).inserted
    }

    /// Refresh pipeline state for all panes in a specific repo root.
    /// Called by the watcher when `.state.json` changes.
    public func refresh(repoRoot: String, panes: [(id: UUID, sessionIDs: [String])]) {
        // Snapshot previous claims for detecting status transitions
        let previousClaims = claimsByPane

        guard let stateFile = PipelineReader.readStateFile(repoRoot: repoRoot) else {
            // State file gone or unreadable — clear all claims for panes in this repo
            for (paneID, _) in panes {
                claimsByPane.removeValue(forKey: paneID)
            }
            return
        }

        // Build a lookup: sessionID -> paneID for efficient matching
        var sessionToPaneID: [String: UUID] = [:]
        for (paneID, sessionIDs) in panes {
            for sid in sessionIDs {
                sessionToPaneID[sid] = paneID
            }
        }

        // Track which panes get a claim this round
        var claimedPaneIDs: Set<UUID> = []

        // Single pass: read each pipeline config once, build both claims and board data
        var boards: [PipelineBoardData] = []
        for (pipelineName, runtime) in stateFile.pipelines {
            guard let config = PipelineReader.readPipelineConfig(repoRoot: repoRoot, pipelineName: pipelineName) else { continue }

            // Read all jobs once — reused for both claim resolution and board data
            let allJobs = PipelineReader.readAllJobs(repoRoot: repoRoot, pipelineName: pipelineName, stages: config.stages)
            let jobLookup: [String: PipelineReader.JobEntry] = allJobs.reduce(into: [:]) { dict, job in
                dict[job.slug] = job
            }

            // Resolve claims for panes
            for (sessionKey, jobSlug) in runtime.claims {
                guard let paneID = sessionToPaneID[sessionKey] else { continue }
                claimedPaneIDs.insert(paneID)

                let entry = jobLookup[jobSlug]
                let status = JobStatus(rawString: runtime.job_statuses[jobSlug]) ?? .active

                claimsByPane[paneID] = PipelineClaimInfo(
                    pipelineName: pipelineName,
                    pipelineDisplayName: config.name,
                    jobSlug: jobSlug,
                    jobTitle: entry?.title ?? jobSlug,
                    currentStageIndex: entry?.stageIndex ?? 0,
                    stages: config.stages,
                    status: status,
                    isPaused: runtime.paused
                )
            }

            // Build board data
            let claimByJob: [String: String] = runtime.claims.reduce(into: [:]) { dict, pair in
                dict[pair.value] = pair.key
            }

            let jobInfos = allJobs.map { job in
                PipelineJobInfo(
                    slug: job.slug,
                    title: job.title,
                    stageIndex: job.stageIndex,
                    stageName: config.stages[job.stageIndex].name,
                    status: JobStatus(rawString: runtime.job_statuses[job.slug]),
                    claimedBy: claimByJob[job.slug],
                    priority: job.priority,
                    labels: job.labels
                )
            }

            // Read archived jobs
            let archivedEntries = PipelineReader.readArchivedJobs(repoRoot: repoRoot, pipelineName: pipelineName)
            let archivedInfos = archivedEntries.map { job in
                PipelineJobInfo(
                    slug: job.slug,
                    title: job.title,
                    stageIndex: -1,
                    stageName: "Archive",
                    status: .completed,
                    claimedBy: nil,
                    priority: job.priority,
                    labels: job.labels
                )
            }

            boards.append(PipelineBoardData(
                pipelineName: pipelineName,
                displayName: config.name,
                stages: config.stages,
                jobs: jobInfos,
                isPaused: runtime.paused,
                archivedJobs: archivedInfos
            ))
        }
        boardDataByRepo[repoRoot] = boards

        // Clear claims for panes in this repo that are no longer claimed
        // and detect interrupted transitions for attention
        for (paneID, _) in panes {
            if claimedPaneIDs.contains(paneID) {
                // Check for status transition to interrupted
                if let oldClaim = previousClaims[paneID],
                   let newClaim = claimsByPane[paneID],
                   oldClaim.status != .interrupted,
                   newClaim.status == .interrupted {
                    onPaneInterrupted?(paneID)
                }
            } else {
                claimsByPane.removeValue(forKey: paneID)
            }
        }
    }

    // MARK: - Mutations

    /// Move a job from one stage directory to another.
    public func moveJob(repoRoot: String, pipelineName: String, jobSlug: String, fromStageIndex: Int, toStageIndex: Int, stages: [PipelineStageDef]) -> Bool {
        guard fromStageIndex != toStageIndex,
              fromStageIndex >= 0, fromStageIndex < stages.count,
              toStageIndex >= 0, toStageIndex < stages.count else { return false }
        return PipelineWriter.moveJob(
            repoRoot: repoRoot,
            pipelineName: pipelineName,
            jobSlug: jobSlug,
            fromStageDir: stages[fromStageIndex].name.lowercased(),
            toStageDir: stages[toStageIndex].name.lowercased()
        )
    }

    /// Add a new job to a stage (defaults to first stage).
    public func addJob(repoRoot: String, pipelineName: String, title: String, stages: [PipelineStageDef], toStageIndex: Int = 0) -> String? {
        guard toStageIndex >= 0, toStageIndex < stages.count else { return nil }
        let nextNum = PipelineReader.nextJobNumber(repoRoot: repoRoot, pipelineName: pipelineName, stages: stages)
        return PipelineWriter.addJob(
            repoRoot: repoRoot,
            pipelineName: pipelineName,
            title: title,
            stageDir: stages[toStageIndex].name.lowercased(),
            number: nextNum
        )
    }

    /// Toggle pause state for a pipeline.
    public func togglePause(repoRoot: String, pipelineName: String) -> Bool {
        PipelineWriter.togglePause(repoRoot: repoRoot, pipelineName: pipelineName)
    }

    /// Remove a job file from its current stage directory.
    public func removeJob(repoRoot: String, pipelineName: String, jobSlug: String, stages: [PipelineStageDef]) -> Bool {
        for stage in stages {
            let stageDir = stage.name.lowercased()
            if PipelineWriter.removeJob(repoRoot: repoRoot, pipelineName: pipelineName, jobSlug: jobSlug, stageDir: stageDir) {
                return true
            }
        }
        return false
    }

    /// Update a job's title in its frontmatter.
    public func updateJobTitle(repoRoot: String, pipelineName: String, jobSlug: String, stages: [PipelineStageDef], newTitle: String) -> Bool {
        PipelineWriter.updateJobTitle(repoRoot: repoRoot, pipelineName: pipelineName, jobSlug: jobSlug, stages: stages, newTitle: newTitle)
    }

    /// Append a log entry to a job file.
    public func appendLogEntry(repoRoot: String, pipelineName: String, jobSlug: String, stages: [PipelineStageDef], message: String) -> Bool {
        PipelineWriter.appendLogEntry(repoRoot: repoRoot, pipelineName: pipelineName, jobSlug: jobSlug, stages: stages, message: message)
    }

    /// Create a new pipeline from a template.
    public func createPipeline(repoRoot: String, pipelineName: String, displayName: String, stages: [PipelineStageDef]) -> Bool {
        PipelineWriter.createPipeline(repoRoot: repoRoot, pipelineName: pipelineName, displayName: displayName, stages: stages)
    }

    /// Delete a pipeline entirely.
    public func deletePipeline(repoRoot: String, pipelineName: String) -> Bool {
        PipelineWriter.deletePipeline(repoRoot: repoRoot, pipelineName: pipelineName)
    }

    /// Add a stage to a pipeline.
    public func addStage(repoRoot: String, pipelineName: String, stageName: String, type: PipelineStageDef.StageType, afterIndex: Int?) -> Bool {
        PipelineWriter.addStage(repoRoot: repoRoot, pipelineName: pipelineName, stageName: stageName, type: type, afterIndex: afterIndex)
    }

    /// Remove a stage from a pipeline (moves jobs to previous stage).
    public func removeStage(repoRoot: String, pipelineName: String, stageIndex: Int) -> Bool {
        PipelineWriter.removeStage(repoRoot: repoRoot, pipelineName: pipelineName, stageIndex: stageIndex)
    }

    /// Change a stage's type (automated/manual).
    public func changeStageType(repoRoot: String, pipelineName: String, stageIndex: Int, newType: PipelineStageDef.StageType) -> Bool {
        PipelineWriter.changeStageType(repoRoot: repoRoot, pipelineName: pipelineName, stageIndex: stageIndex, newType: newType)
    }
}
