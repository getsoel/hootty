import Foundation

// MARK: - Stage

public enum StageType: String, Codable, Sendable {
    case automated
    case manual
}

public struct Stage: Sendable {
    public var name: String
    public var type: StageType
    public var command: String?

    public init(name: String, type: StageType, command: String? = nil) {
        self.name = name
        self.type = type
        self.command = command
    }

    /// Directory name: lowercased, spaces to hyphens
    public var directoryName: String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

// MARK: - Pipeline Config (pipeline.yaml)

public struct PipelineSettings: Sendable {
    public var pauseOnError: Bool
    public var maxClaims: Int?
    public var variables: [String: String]

    public init(pauseOnError: Bool = true, maxClaims: Int? = nil, variables: [String: String] = [:]) {
        self.pauseOnError = pauseOnError
        self.maxClaims = maxClaims
        self.variables = variables
    }
}

public struct PipelineConfig: Sendable {
    public var name: String
    public var stages: [Stage]
    public var settings: PipelineSettings

    public init(name: String, stages: [Stage], settings: PipelineSettings = PipelineSettings()) {
        self.name = name
        self.stages = stages
        self.settings = settings
    }
}

// MARK: - Repo Config (config.yaml)

public struct RepoConfig: Sendable {
    public var defaultPipeline: String

    public init(defaultPipeline: String = "default") {
        self.defaultPipeline = defaultPipeline
    }
}

// MARK: - Job Status

public enum JobStatus: String, Codable, Sendable {
    case queued
    case active
    case interrupted
    case completed
}

// MARK: - Job

public struct Job: Sendable {
    public var filename: String        // e.g. "001-auth-refactor.md"
    public var slug: String            // e.g. "001-auth-refactor"
    public var number: Int             // e.g. 1
    public var title: String           // from frontmatter
    public var priority: String?       // from frontmatter
    public var labels: [String]        // from frontmatter
    public var created: String?        // from frontmatter (ISO 8601 string)
    public var prompt: String          // body up to first ## heading
    public var fullBody: String        // entire body after frontmatter
    public var stage: String           // current stage directory name

    public init(
        filename: String, slug: String, number: Int, title: String,
        priority: String? = nil, labels: [String] = [], created: String? = nil,
        prompt: String = "", fullBody: String = "", stage: String = ""
    ) {
        self.filename = filename
        self.slug = slug
        self.number = number
        self.title = title
        self.priority = priority
        self.labels = labels
        self.created = created
        self.prompt = prompt
        self.fullBody = fullBody
        self.stage = stage
    }
}

// MARK: - Pipeline State (.state.json)

public struct PipelineStateEntry: Codable, Sendable {
    public var claims: [String: String]          // session_id → job_slug
    public var jobStatuses: [String: JobStatus]  // job_slug → status
    public var paused: Bool
    public var injectionTarget: String?

    public init(
        claims: [String: String] = [:],
        jobStatuses: [String: JobStatus] = [:],
        paused: Bool = false,
        injectionTarget: String? = nil
    ) {
        self.claims = claims
        self.jobStatuses = jobStatuses
        self.paused = paused
        self.injectionTarget = injectionTarget
    }

    enum CodingKeys: String, CodingKey {
        case claims
        case jobStatuses = "job_statuses"
        case paused
        case injectionTarget = "injection_target"
    }
}

public struct PipelineState: Codable, Sendable {
    public var pipelines: [String: PipelineStateEntry]

    public init(pipelines: [String: PipelineStateEntry] = [:]) {
        self.pipelines = pipelines
    }
}

// MARK: - Errors

public enum PipelineError: Error, CustomStringConvertible {
    case noPipelineDirectory
    case pipelineNotFound(String)
    case pipelineAlreadyExists(String)
    case jobNotFound(String)
    case stageNotFound(String)
    case alreadyClaimed(String)
    case noClaim
    case pipelinePaused
    case noJobsAvailable(String)
    case jobMoved
    case lockFailed
    case invalidConfig(String)
    case gitError(String)
    case missingArgument(String)
    case fileError(String)
    case unknownTemplate(String)

    public var description: String {
        switch self {
        case .noPipelineDirectory:
            return "No .hootty/pipeline/ directory found. Run `pipeline init` to create one."
        case .pipelineNotFound(let name):
            return "Pipeline \"\(name)\" not found."
        case .pipelineAlreadyExists(let name):
            return "Pipeline \"\(name)\" already exists."
        case .jobNotFound(let slug):
            return "Job \"\(slug)\" not found."
        case .stageNotFound(let name):
            return "Stage \"\(name)\" not found."
        case .alreadyClaimed(let job):
            return "You already have a claim on \"\(job)\". Run `pipeline release` first."
        case .noClaim:
            return "No active claim. Run `pipeline claim` first."
        case .pipelinePaused:
            return "Pipeline is paused. Run `pipeline play` to resume."
        case .noJobsAvailable(let pipeline):
            return "No jobs available to claim in pipeline \"\(pipeline)\"."
        case .jobMoved:
            return "Job has moved since your last action. Run `pipeline current-job` to see current state."
        case .lockFailed:
            return "Failed to acquire lock on .state.json."
        case .invalidConfig(let msg):
            return "Invalid configuration: \(msg)"
        case .gitError(let msg):
            return "Git error: \(msg)"
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .fileError(let msg):
            return "File error: \(msg)"
        case .unknownTemplate(let name):
            return "Unknown template: \"\(name)\". Available: simple, review, full-ci"
        }
    }
}

// MARK: - Result Types

public enum ClaimResult {
    case claimed(job: Job, pipeline: String, prompt: String?)
    case noJobsAvailable(pipeline: String)
    case alreadyClaimed(currentJob: String, pipeline: String)
}

public enum AdvanceResult {
    case advanced(job: Job, pipeline: String, fromStage: String, toStage: String, nextPrompt: String?)
    case manual(job: Job, pipeline: String, fromStage: String, toStage: String)
    case completed(job: Job, pipeline: String, fromStage: String)
    case noClaim
    case paused
}

// MARK: - Helpers

public func deriveSlug(from title: String) -> String {
    var slug = title.lowercased()
    slug = slug.map { $0.isLetter || $0.isNumber ? $0 : Character("-") }
        .map(String.init).joined()
    // Collapse consecutive hyphens
    while slug.contains("--") {
        slug = slug.replacingOccurrences(of: "--", with: "-")
    }
    // Trim leading/trailing hyphens
    slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    // Max 50 characters
    if slug.count > 50 {
        slug = String(slug.prefix(50))
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    return slug
}

public func jobNumber(from filename: String) -> Int? {
    let name = (filename as NSString).deletingPathExtension
    let parts = name.split(separator: "-", maxSplits: 1)
    guard let first = parts.first else { return nil }
    return Int(first)
}
