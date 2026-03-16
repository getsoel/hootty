import Foundation
import PipelineKit

// MARK: - Typealiases for PipelineKit types (re-exported for Hootty target)

/// Backward-compatible alias: use `PipelineKit.Stage` everywhere.
public typealias PipelineStageDef = PipelineKit.Stage

public extension PipelineKit.Stage {
    /// Allow `PipelineStageDef.StageType` to resolve to `PipelineKit.StageType`.
    typealias StageType = PipelineKit.StageType
}

public typealias JobStatus = PipelineKit.JobStatus
public typealias PipelineTemplate = PipelineKit.PipelineTemplate

public extension PipelineKit.PipelineTemplate {
    var displayName: String {
        switch self {
        case .simple: "Simple"
        case .review: "Review"
        case .fullCi: "Full CI"
        }
    }

    var stages: [PipelineKit.Stage] {
        config.stages
    }
}

// MARK: - Resolved Claim Info (for display)

/// A single job as it appears on the board (stage-resolved, with metadata).
public struct PipelineJobInfo: Identifiable, Sendable {
    public let id: String // jobSlug
    public let slug: String
    public let title: String
    public let stageIndex: Int
    public let stageName: String
    public let status: PipelineKit.JobStatus? // nil = unclaimed
    public let claimedBy: String? // session key if claimed
    public let priority: String? // "low", "medium", "high", "critical"
    public let labels: [String]

    public init(slug: String, title: String, stageIndex: Int, stageName: String, status: PipelineKit.JobStatus?, claimedBy: String?, priority: String? = nil, labels: [String] = []) {
        self.id = slug
        self.slug = slug
        self.title = title
        self.stageIndex = stageIndex
        self.stageName = stageName
        self.status = status
        self.claimedBy = claimedBy
        self.priority = priority
        self.labels = labels
    }
}

/// Full board snapshot for a single pipeline within a repo.
public struct PipelineBoardData: Identifiable, Sendable {
    public let id: String // pipelineName
    public let pipelineName: String
    public let displayName: String
    public let stages: [PipelineKit.Stage]
    public let jobs: [PipelineJobInfo]
    public let isPaused: Bool
    /// Jobs grouped by stage index, in stage order. Pre-computed at init time.
    public let jobsByStage: [[PipelineJobInfo]]
    /// Archived jobs (from archive/ directory).
    public let archivedJobs: [PipelineJobInfo]

    /// Count of jobs needing human attention (in manual stages, not completed).
    public var jobsNeedingAttention: Int {
        jobs.filter { job in
            guard job.stageIndex < stages.count else { return false }
            let stage = stages[job.stageIndex]
            return stage.type == .manual && (job.status == .interrupted || job.status == nil || job.status == .queued)
        }.count
    }

    public init(pipelineName: String, displayName: String, stages: [PipelineKit.Stage], jobs: [PipelineJobInfo], isPaused: Bool, archivedJobs: [PipelineJobInfo] = []) {
        self.id = pipelineName
        self.pipelineName = pipelineName
        self.displayName = displayName
        self.stages = stages
        self.jobs = jobs
        self.isPaused = isPaused
        self.jobsByStage = stages.indices.map { stageIdx in
            jobs.filter { $0.stageIndex == stageIdx }
        }
        self.archivedJobs = archivedJobs
    }
}

// MARK: - Resolved Claim Info (for display)

public struct PipelineClaimInfo: Sendable {
    public let pipelineName: String
    public let pipelineDisplayName: String
    public let jobSlug: String
    public let jobTitle: String
    public let currentStageIndex: Int
    public let stages: [PipelineKit.Stage]
    public let status: PipelineKit.JobStatus
    public let isPaused: Bool

    public init(pipelineName: String, pipelineDisplayName: String, jobSlug: String, jobTitle: String, currentStageIndex: Int, stages: [PipelineKit.Stage], status: PipelineKit.JobStatus, isPaused: Bool) {
        self.pipelineName = pipelineName
        self.pipelineDisplayName = pipelineDisplayName
        self.jobSlug = jobSlug
        self.jobTitle = jobTitle
        self.currentStageIndex = currentStageIndex
        self.stages = stages
        self.status = status
        self.isPaused = isPaused
    }
}
