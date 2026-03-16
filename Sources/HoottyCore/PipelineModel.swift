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

    public init() {}

    /// Get the claim info for a specific pane, if any.
    public func claimInfo(for paneID: UUID) -> PipelineClaimInfo? {
        claimsByPane[paneID]
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

            boards.append(PipelineBoardData(
                pipelineName: pipelineName,
                displayName: config.name,
                stages: config.stages,
                jobs: jobInfos,
                isPaused: runtime.paused
            ))
        }
        boardDataByRepo[repoRoot] = boards

        // Clear claims for panes in this repo that are no longer claimed
        for (paneID, _) in panes where !claimedPaneIDs.contains(paneID) {
            claimsByPane.removeValue(forKey: paneID)
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
}
