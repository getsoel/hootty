import Foundation

// MARK: - Pipeline Config (from pipeline.yaml)

public struct PipelineStageDef: Sendable {
    public let name: String
    public let type: StageType
    public let command: String?

    public enum StageType: String, Sendable {
        case automated
        case manual
    }

    public init(name: String, type: StageType, command: String? = nil) {
        self.name = name
        self.type = type
        self.command = command
    }
}

public struct PipelineConfig: Sendable {
    public let name: String
    public let stages: [PipelineStageDef]

    public init(name: String, stages: [PipelineStageDef]) {
        self.name = name
        self.stages = stages
    }
}

// MARK: - Pipeline Runtime State (from .state.json)

public struct PipelineRuntimeState: Codable, Sendable {
    public let claims: [String: String]
    public let job_statuses: [String: String]
    public let paused: Bool
}

public struct PipelineStateFile: Codable, Sendable {
    public let pipelines: [String: PipelineRuntimeState]
}

// MARK: - Job Status

public enum JobStatus: String, Sendable {
    case active
    case interrupted
    case completed

    public init?(rawString: String?) {
        guard let rawString else { return nil }
        self.init(rawValue: rawString)
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
    public let status: JobStatus? // nil = unclaimed
    public let claimedBy: String? // session key if claimed
    public let priority: String? // "low", "medium", "high", "critical"
    public let labels: [String]

    public init(slug: String, title: String, stageIndex: Int, stageName: String, status: JobStatus?, claimedBy: String?, priority: String? = nil, labels: [String] = []) {
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
    public let stages: [PipelineStageDef]
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
            return stage.type == .manual && (job.status == .interrupted || job.status == nil)
        }.count
    }

    public init(pipelineName: String, displayName: String, stages: [PipelineStageDef], jobs: [PipelineJobInfo], isPaused: Bool, archivedJobs: [PipelineJobInfo] = []) {
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

// MARK: - Pipeline Templates

public enum PipelineTemplate: String, CaseIterable, Sendable {
    case simple
    case review
    case fullCI = "full-ci"

    public var displayName: String {
        switch self {
        case .simple: "Simple"
        case .review: "Review"
        case .fullCI: "Full CI"
        }
    }

    public var stages: [PipelineStageDef] {
        switch self {
        case .simple:
            [
                PipelineStageDef(name: "Backlog", type: .manual),
                PipelineStageDef(name: "Run", type: .automated),
                PipelineStageDef(name: "Done", type: .manual)
            ]
        case .review:
            [
                PipelineStageDef(name: "Backlog", type: .manual),
                PipelineStageDef(name: "Implement", type: .automated),
                PipelineStageDef(name: "Review", type: .manual),
                PipelineStageDef(name: "Done", type: .manual)
            ]
        case .fullCI:
            [
                PipelineStageDef(name: "Backlog", type: .manual),
                PipelineStageDef(name: "Implement", type: .automated),
                PipelineStageDef(name: "Review", type: .manual),
                PipelineStageDef(name: "Test", type: .automated, command: "Write tests for the changes you just made"),
                PipelineStageDef(name: "Commit", type: .automated, command: "/commit"),
                PipelineStageDef(name: "Done", type: .manual)
            ]
        }
    }
}

// MARK: - Resolved Claim Info (for display)

public struct PipelineClaimInfo: Sendable {
    public let pipelineName: String
    public let pipelineDisplayName: String
    public let jobSlug: String
    public let jobTitle: String
    public let currentStageIndex: Int
    public let stages: [PipelineStageDef]
    public let status: JobStatus
    public let isPaused: Bool

    public init(pipelineName: String, pipelineDisplayName: String, jobSlug: String, jobTitle: String, currentStageIndex: Int, stages: [PipelineStageDef], status: JobStatus, isPaused: Bool) {
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
