import Foundation
import PipelineKit

/// Observable model holding resolved pipeline claim info for each pane.
/// Updated by the PipelineWatcher whenever `.hootty/pipeline/.state.json` changes.
@MainActor
@Observable
public final class PipelineModel {
    /// Relative path from repo root to the pipeline directory.
    public static let directoryPath = ".hootty/pipeline"

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

    /// Cached PipelineStorage instances per repo root (internal bookkeeping, no UI relevance).
    @ObservationIgnored private var storageByRepo: [String: PipelineStorage] = [:]

    public init() {}

    /// Get or create a PipelineStorage for a repo root.
    private func storage(for repoRoot: String) -> PipelineStorage {
        if let existing = storageByRepo[repoRoot] {
            return existing
        }
        let rootPath = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)
        let storage = PipelineStorage(rootPath: rootPath)
        storageByRepo[repoRoot] = storage
        return storage
    }

    /// Check whether a pipeline directory exists at the given repo root.
    public nonisolated static func hasPipeline(repoRoot: String) -> Bool {
        var isDir: ObjCBool = false
        let path = (repoRoot as NSString).appendingPathComponent(directoryPath)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

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

    // MARK: - Refresh

    /// Refresh pipeline state for all panes in a specific repo root.
    /// Called by the watcher when `.state.json` changes.
    public func refresh(repoRoot: String, panes: [(id: UUID, sessionIDs: [String])]) {
        let storage = storage(for: repoRoot)

        // Snapshot previous claims for detecting status transitions
        let previousClaims = claimsByPane

        let stateFile = storage.pipelineState()
        guard !stateFile.pipelines.isEmpty else {
            // State file gone or empty — clear all claims for panes in this repo
            for (paneID, _) in panes {
                claimsByPane.removeValue(forKey: paneID)
            }
            boardDataByRepo[repoRoot] = []
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
            guard let config = try? storage.pipelineConfig(name: pipelineName) else { continue }

            // Read all jobs once (pass config to avoid re-reading pipeline.yaml)
            let allJobEntries = (try? storage.allJobs(pipeline: pipelineName, config: config)) ?? []

            // Build stage index lookup: directoryName → index
            let stageIndexByDir: [String: Int] = config.stages.enumerated().reduce(into: [:]) { dict, pair in
                dict[pair.element.directoryName] = pair.offset
            }

            // Build job lookup by slug
            let jobLookup: [String: (stageIndex: Int, job: PipelineKit.Job)] = allJobEntries.reduce(into: [:]) { dict, entry in
                let stageIndex = stageIndexByDir[entry.stage] ?? 0
                dict[entry.job.slug] = (stageIndex: stageIndex, job: entry.job)
            }

            // Resolve claims for panes
            for (sessionKey, jobSlug) in runtime.claims {
                guard let paneID = sessionToPaneID[sessionKey] else { continue }
                claimedPaneIDs.insert(paneID)

                let entry = jobLookup[jobSlug]
                let status = runtime.jobStatuses[jobSlug] ?? .active

                claimsByPane[paneID] = PipelineClaimInfo(
                    pipelineName: pipelineName,
                    pipelineDisplayName: config.name,
                    jobSlug: jobSlug,
                    jobTitle: entry?.job.title ?? jobSlug,
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

            let jobInfos = allJobEntries.map { entry in
                let stageIndex = stageIndexByDir[entry.stage] ?? 0
                let stageName = stageIndex < config.stages.count ? config.stages[stageIndex].name : entry.stage
                return PipelineJobInfo(
                    slug: entry.job.slug,
                    title: entry.job.title,
                    stageIndex: stageIndex,
                    stageName: stageName,
                    status: runtime.jobStatuses[entry.job.slug],
                    claimedBy: claimByJob[entry.job.slug],
                    priority: entry.job.priority,
                    labels: entry.job.labels
                )
            }

            // Read archived jobs
            let archivedJobs = (try? storage.jobsInStage(pipeline: pipelineName, stage: "archive")) ?? []
            let archivedInfos = archivedJobs.map { job in
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

    // MARK: - Read Methods (for views)

    /// Read the markdown body (after frontmatter) of a job file.
    public func readJobBody(repoRoot: String, pipelineName: String, jobSlug: String) -> String? {
        let storage = storage(for: repoRoot)
        guard let result = try? storage.findJob(pipeline: pipelineName, slug: jobSlug) else { return nil }
        let body = result.job.fullBody
        return body.isEmpty ? nil : body
    }

    /// Read the full raw content of a job file (for detail view with ## sections).
    public func readFullJobContent(repoRoot: String, pipelineName: String, jobSlug: String) -> String? {
        let storage = storage(for: repoRoot)
        guard let result = try? storage.findJob(pipeline: pipelineName, slug: jobSlug) else { return nil }
        let path = storage.jobFilePath(pipeline: pipelineName, stage: result.stage, filename: result.job.filename)
        guard let data = FileManager.default.contents(atPath: path.path),
              let content = String(data: data, encoding: .utf8) else { return nil }
        return content
    }

    // MARK: - Mutations

    /// Move a job from one stage directory to another.
    public func moveJob(repoRoot: String, pipelineName: String, jobSlug: String, fromStageIndex: Int, toStageIndex: Int, stages: [PipelineKit.Stage]) -> Bool {
        guard fromStageIndex != toStageIndex,
              fromStageIndex >= 0, fromStageIndex < stages.count,
              toStageIndex >= 0, toStageIndex < stages.count else { return false }

        let storage = storage(for: repoRoot)
        guard let result = try? storage.findJob(pipeline: pipelineName, slug: jobSlug) else { return false }

        do {
            try storage.moveJobFile(
                pipeline: pipelineName,
                filename: result.job.filename,
                fromStage: stages[fromStageIndex].directoryName,
                toStage: stages[toStageIndex].directoryName
            )
            return true
        } catch {
            return false
        }
    }

    /// Add a new job to a stage (defaults to first stage).
    public func addJob(repoRoot: String, pipelineName: String, title: String, stages: [PipelineKit.Stage], toStageIndex: Int = 0) -> String? {
        guard toStageIndex >= 0, toStageIndex < stages.count else { return nil }

        let storage = storage(for: repoRoot)
        guard let nextNum = try? storage.nextJobNumber(pipeline: pipelineName) else { return nil }

        let slugBody = PipelineKit.deriveSlug(from: title)
        let slug = String(format: "%03d-%@", nextNum, slugBody)
        let filename = "\(slug).md"

        let content = PipelineKit.serializeJob(
            title: title,
            priority: nil,
            labels: [],
            created: ISO8601DateFormatter().string(from: Date()),
            body: ""
        )

        do {
            try storage.writeJob(
                pipeline: pipelineName,
                stage: stages[toStageIndex].directoryName,
                filename: filename,
                content: content
            )
            return slug
        } catch {
            return nil
        }
    }

    /// Toggle pause state for a pipeline.
    public func togglePause(repoRoot: String, pipelineName: String) -> Bool {
        let storage = storage(for: repoRoot)
        do {
            try storage.withStateLock {
                var state = storage.pipelineState()
                var entry = state.pipelines[pipelineName] ?? PipelineKit.PipelineStateEntry()
                entry.paused.toggle()
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)
            }
            return true
        } catch {
            return false
        }
    }

    /// Remove a job file from its current stage directory.
    public func removeJob(repoRoot: String, pipelineName: String, jobSlug: String) -> Bool {
        let storage = storage(for: repoRoot)
        guard let result = try? storage.findJob(pipeline: pipelineName, slug: jobSlug) else { return false }

        do {
            try storage.deleteJobFile(pipeline: pipelineName, stage: result.stage, filename: result.job.filename)
            return true
        } catch {
            return false
        }
    }

    /// Update a job's title in its frontmatter.
    public func updateJobTitle(repoRoot: String, pipelineName: String, jobSlug: String, newTitle: String) -> Bool {
        let storage = storage(for: repoRoot)
        guard let result = try? storage.findJob(pipeline: pipelineName, slug: jobSlug) else { return false }

        let path = storage.jobFilePath(pipeline: pipelineName, stage: result.stage, filename: result.job.filename)
        guard let data = FileManager.default.contents(atPath: path.path),
              let content = String(data: data, encoding: .utf8) else { return false }

        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        var newLines: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontmatter.toggle()
                newLines.append(line)
                continue
            }
            if inFrontmatter, line.trimmingCharacters(in: .whitespaces).hasPrefix("title:") {
                newLines.append("title: \(newTitle)")
            } else {
                newLines.append(line)
            }
        }
        let updated = newLines.joined(separator: "\n")
        return FileManager.default.createFile(atPath: path.path, contents: updated.data(using: .utf8))
    }

    /// Append a log entry to a job file.
    public func appendLogEntry(repoRoot: String, pipelineName: String, jobSlug: String, message: String) -> Bool {
        let storage = storage(for: repoRoot)
        guard let result = try? storage.findJob(pipeline: pipelineName, slug: jobSlug) else { return false }

        do {
            try storage.appendLog(pipeline: pipelineName, stage: result.stage, filename: result.job.filename, message: message)
            return true
        } catch {
            return false
        }
    }

    /// Create a new pipeline from stages.
    public func createPipeline(repoRoot: String, pipelineName: String, displayName: String, stages: [PipelineKit.Stage]) -> Bool {
        let storage = storage(for: repoRoot)
        let config = PipelineKit.PipelineConfig(name: displayName, stages: stages)

        do {
            try storage.createPipeline(name: pipelineName, config: config)
            // Ensure state entry
            try storage.withStateLock {
                var state = storage.pipelineState()
                if state.pipelines[pipelineName] == nil {
                    state.pipelines[pipelineName] = PipelineKit.PipelineStateEntry()
                }
                try storage.savePipelineState(state)
            }
            return true
        } catch {
            return false
        }
    }

    /// Delete a pipeline entirely.
    public func deletePipeline(repoRoot: String, pipelineName: String) -> Bool {
        let storage = storage(for: repoRoot)
        do {
            try storage.deletePipeline(name: pipelineName)
            // Remove state entry
            try storage.withStateLock {
                var state = storage.pipelineState()
                state.pipelines.removeValue(forKey: pipelineName)
                try storage.savePipelineState(state)
            }
            return true
        } catch {
            return false
        }
    }

    /// Add a stage to a pipeline.
    public func addStage(repoRoot: String, pipelineName: String, stageName: String, type: PipelineKit.StageType, afterIndex: Int?) -> Bool {
        let storage = storage(for: repoRoot)
        guard var config = try? storage.pipelineConfig(name: pipelineName) else { return false }

        let newStage = PipelineKit.Stage(name: stageName, type: type)
        let insertIndex = (afterIndex ?? config.stages.count - 1) + 1
        config.stages.insert(newStage, at: min(insertIndex, config.stages.count))

        do {
            try storage.savePipelineConfig(name: pipelineName, config: config)
            let stageDir = storage.jobFilePath(pipeline: pipelineName, stage: newStage.directoryName, filename: "").deletingLastPathComponent()
            try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// Remove a stage from a pipeline (moves jobs to previous stage).
    public func removeStage(repoRoot: String, pipelineName: String, stageIndex: Int) -> Bool {
        let storage = storage(for: repoRoot)
        guard var config = try? storage.pipelineConfig(name: pipelineName) else { return false }
        guard stageIndex >= 0, stageIndex < config.stages.count, config.stages.count > 1 else { return false }

        let removedStage = config.stages[stageIndex]
        let targetIndex = max(0, stageIndex - 1)
        let targetStage = config.stages[stageIndex == 0 ? 1 : targetIndex]

        // Move jobs from removed stage to target using PipelineStorage methods
        let jobs = (try? storage.jobsInStage(pipeline: pipelineName, stage: removedStage.directoryName)) ?? []
        for job in jobs {
            try? storage.moveJobFile(pipeline: pipelineName, filename: job.filename, fromStage: removedStage.directoryName, toStage: targetStage.directoryName)
        }

        // Remove the now-empty stage directory
        let removedDir = storage.jobFilePath(pipeline: pipelineName, stage: removedStage.directoryName, filename: "").deletingLastPathComponent()
        try? FileManager.default.removeItem(at: removedDir)

        config.stages.remove(at: stageIndex)

        do {
            try storage.savePipelineConfig(name: pipelineName, config: config)
            return true
        } catch {
            return false
        }
    }

    /// Change a stage's type (automated/manual).
    public func changeStageType(repoRoot: String, pipelineName: String, stageIndex: Int, newType: PipelineKit.StageType) -> Bool {
        let storage = storage(for: repoRoot)
        guard var config = try? storage.pipelineConfig(name: pipelineName) else { return false }
        guard stageIndex >= 0, stageIndex < config.stages.count else { return false }

        config.stages[stageIndex].type = newType

        do {
            try storage.savePipelineConfig(name: pipelineName, config: config)
            return true
        } catch {
            return false
        }
    }
}
