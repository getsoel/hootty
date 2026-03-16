import Foundation

// MARK: - Events (daemon → clients)

public struct PipelineEvent: Codable, Sendable {
    public let event: String
    public var pipeline: String?
    public var job: String?
    public var from: String?
    public var to: String?
    public var status: String?
    public var message: String?
    public var prompt: String?
    public var paneID: String?

    public init(event: String, pipeline: String? = nil, job: String? = nil,
                from: String? = nil, to: String? = nil, status: String? = nil,
                message: String? = nil, prompt: String? = nil, paneID: String? = nil) {
        self.event = event
        self.pipeline = pipeline
        self.job = job
        self.from = from
        self.to = to
        self.status = status
        self.message = message
        self.prompt = prompt
        self.paneID = paneID
    }

    /// Factory methods
    public static func jobMoved(pipeline: String, job: String, from: String, to: String) -> PipelineEvent {
        PipelineEvent(event: "job_moved", pipeline: pipeline, job: job, from: from, to: to)
    }

    public static func jobStatusChanged(pipeline: String, job: String, status: JobStatus) -> PipelineEvent {
        PipelineEvent(event: "job_status_changed", pipeline: pipeline, job: job, status: status.rawValue)
    }

    public static func jobAdded(pipeline: String, job: String, stage: String) -> PipelineEvent {
        PipelineEvent(event: "job_added", pipeline: pipeline, job: job, to: stage)
    }

    public static func jobRemoved(pipeline: String, job: String, stage: String) -> PipelineEvent {
        PipelineEvent(event: "job_removed", pipeline: pipeline, job: job, from: stage)
    }

    public static func pipelinePaused(pipeline: String) -> PipelineEvent {
        PipelineEvent(event: "pipeline_paused", pipeline: pipeline)
    }

    public static func pipelineResumed(pipeline: String) -> PipelineEvent {
        PipelineEvent(event: "pipeline_resumed", pipeline: pipeline)
    }

    public static func runnerIdle(paneID: String) -> PipelineEvent {
        PipelineEvent(event: "runner_idle", paneID: paneID)
    }

    public static func error(pipeline: String? = nil, job: String? = nil, message: String) -> PipelineEvent {
        PipelineEvent(event: "error", pipeline: pipeline, job: job, message: message)
    }

    public static func inject(paneID: String, prompt: String, job: String) -> PipelineEvent {
        PipelineEvent(event: "inject", job: job, prompt: prompt, paneID: paneID)
    }

    public static func daemonReady() -> PipelineEvent {
        PipelineEvent(event: "daemon_ready")
    }

    enum CodingKeys: String, CodingKey {
        case event, pipeline, job, from, to, status, message, prompt
        case paneID = "pane_id"
    }

    /// Encode to a single-line JSON string with newline terminator
    public func jsonLine() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var data = (try? encoder.encode(self)) ?? Data("{}".utf8)
        data.append(contentsOf: "\n".utf8)
        return data
    }
}

// MARK: - Commands (clients → daemon)

public struct DaemonCommand: Codable, Sendable {
    public let command: String
    public var pipeline: String?
    public var job: String?
    public var title: String?
    public var prompt: String?
    public var stage: String?
    public var paneID: String?
    public var sessionID: String?
    public var type: String?
    public var id: String?

    public init(command: String, pipeline: String? = nil, job: String? = nil,
                title: String? = nil, prompt: String? = nil, stage: String? = nil,
                paneID: String? = nil, sessionID: String? = nil,
                type: String? = nil, id: String? = nil) {
        self.command = command
        self.pipeline = pipeline
        self.job = job
        self.title = title
        self.prompt = prompt
        self.stage = stage
        self.paneID = paneID
        self.sessionID = sessionID
        self.type = type
        self.id = id
    }

    enum CodingKeys: String, CodingKey {
        case command, pipeline, job, title, prompt, stage, type, id
        case paneID = "pane_id"
        case sessionID = "session_id"
    }
}

// MARK: - Daemon Response

public struct DaemonResponse: Codable, Sendable {
    public let success: Bool
    public var message: String?

    public init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
    }

    public func jsonLine() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var data = (try? encoder.encode(self)) ?? Data("{}".utf8)
        data.append(contentsOf: "\n".utf8)
        return data
    }
}

// MARK: - Board Snapshot (for diffing)

public struct BoardSnapshot: Equatable, Sendable {
    public var pipelines: [String: PipelineSnapshot]

    public init(pipelines: [String: PipelineSnapshot] = [:]) {
        self.pipelines = pipelines
    }
}

public struct PipelineSnapshot: Equatable, Sendable {
    /// Maps job slug → stage directory name
    public var jobLocations: [String: String]
    public var claims: [String: String]
    public var statuses: [String: JobStatus]
    public var paused: Bool

    public init(jobLocations: [String: String] = [:], claims: [String: String] = [:],
                statuses: [String: JobStatus] = [:], paused: Bool = false) {
        self.jobLocations = jobLocations
        self.claims = claims
        self.statuses = statuses
        self.paused = paused
    }
}

/// Compute events from old → new snapshot
public func diffSnapshots(old: BoardSnapshot, new: BoardSnapshot) -> [PipelineEvent] {
    var events: [PipelineEvent] = []

    let allPipelines = Set(old.pipelines.keys).union(new.pipelines.keys)
    for pipeline in allPipelines {
        let oldP = old.pipelines[pipeline] ?? PipelineSnapshot()
        let newP = new.pipelines[pipeline] ?? PipelineSnapshot()

        // Job moves
        for (slug, newStage) in newP.jobLocations {
            if let oldStage = oldP.jobLocations[slug], oldStage != newStage {
                events.append(.jobMoved(pipeline: pipeline, job: slug, from: oldStage, to: newStage))
            } else if oldP.jobLocations[slug] == nil {
                events.append(.jobAdded(pipeline: pipeline, job: slug, stage: newStage))
            }
        }

        // Job removals
        for (slug, oldStage) in oldP.jobLocations {
            if newP.jobLocations[slug] == nil {
                events.append(.jobRemoved(pipeline: pipeline, job: slug, stage: oldStage))
            }
        }

        // Status changes
        for (slug, newStatus) in newP.statuses {
            let oldStatus = oldP.statuses[slug]
            if oldStatus != newStatus {
                events.append(.jobStatusChanged(pipeline: pipeline, job: slug, status: newStatus))
            }
        }

        // Pause state
        if oldP.paused != newP.paused {
            events.append(newP.paused
                ? .pipelinePaused(pipeline: pipeline)
                : .pipelineResumed(pipeline: pipeline))
        }
    }

    return events
}
