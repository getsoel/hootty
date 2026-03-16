import Foundation

public class PipelineEngine {
    public let storage: PipelineStorage
    public let sessionID: String
    public var templateStore: TemplateStore?

    public init(storage: PipelineStorage, sessionID: String, templateStore: TemplateStore? = nil) {
        self.storage = storage
        self.sessionID = sessionID
        self.templateStore = templateStore
    }

    // MARK: - Init

    /// Initialize a new pipeline (creates .hootty/pipeline/ if needed)
    public func initPipeline(name: String?, template: String?) throws {
        let pipelineName = name ?? "default"
        let fm = FileManager.default

        // Create .hootty/pipeline/ root if it doesn't exist
        if !fm.fileExists(atPath: storage.rootPath) {
            try storage.initRoot(defaultPipeline: pipelineName)
        } else if name != nil {
            // Update default if creating a named pipeline and config.yaml exists
            // Only set default if this is the first pipeline
            if storage.listPipelines().isEmpty {
                try storage.saveRepoConfig(RepoConfig(defaultPipeline: pipelineName))
            }
        }

        // Resolve template: prefer global template store, fall back to built-in
        var config: PipelineConfig
        if let templateName = template {
            if let store = templateStore {
                config = try store.loadTemplate(name: templateName)
            } else if let tmpl = PipelineTemplate(rawValue: templateName) {
                config = tmpl.config
            } else {
                throw PipelineError.unknownTemplate(templateName)
            }
        } else {
            if let store = templateStore {
                config = (try? store.loadTemplate(name: "review")) ?? PipelineTemplate.review.config
            } else {
                config = PipelineTemplate.review.config
            }
        }
        config.name = pipelineName.capitalized + " Pipeline"

        try storage.createPipeline(name: pipelineName, config: config)
    }

    /// Delete a pipeline
    public func deletePipeline(name: String) throws {
        try storage.deletePipeline(name: name)

        // Clean up state
        try storage.withStateLock {
            var state = storage.pipelineState()
            state.pipelines.removeValue(forKey: name)
            try storage.savePipelineState(state)
        }

        // Update default if needed
        var repoConfig = storage.repoConfig()
        if repoConfig.defaultPipeline == name {
            let remaining = storage.listPipelines()
            repoConfig.defaultPipeline = remaining.first ?? "default"
            try storage.saveRepoConfig(repoConfig)
        }
    }

    // MARK: - Status

    public func status(pipeline: String?, all: Bool, json: Bool, formatContext: Bool) throws -> String {
        if all {
            return try statusAll(json: json, formatContext: formatContext)
        }

        let pipelineName = try resolveDefaultPipeline(pipeline)
        if json {
            return try statusJSON(pipeline: pipelineName)
        }
        if formatContext {
            return try statusContext()
        }
        return try statusHuman(pipeline: pipelineName)
    }

    private func statusAll(json _: Bool, formatContext: Bool) throws -> String {
        let pipelines = storage.listPipelines()
        if pipelines.isEmpty { return "No pipelines found." }

        if formatContext {
            return try statusContext()
        }

        var output: [String] = []
        for name in pipelines {
            try output.append(statusHuman(pipeline: name))
            output.append("")
        }
        return output.joined(separator: "\n")
    }

    private func statusHuman(pipeline: String) throws -> String {
        let config = try storage.pipelineConfig(name: pipeline)
        let state = storage.pipelineState()
        let entry = state.pipelines[pipeline] ?? PipelineStateEntry()

        var lines: [String] = []
        let totalJobs = try storage.allJobs(pipeline: pipeline).count
        let pausedStr = entry.paused ? " (paused)" : ""
        lines.append("Pipeline: \(pipeline)\(pausedStr) (\(totalJobs) jobs)")
        lines.append("")

        for stage in config.stages {
            let jobs = try storage.jobsInStage(pipeline: pipeline, stage: stage.directoryName)
            let typeIndicator = stage.type == .automated ? " [auto]" : ""
            if jobs.isEmpty {
                lines.append("  \(stage.name)\(typeIndicator): (empty)")
            } else {
                let jobStrs = jobs.map { job in
                    let status = entry.jobStatuses[job.slug] ?? .queued
                    let claimedBy = entry.claims.first(where: { $0.value == job.slug })?.key
                    var indicators: [String] = []
                    if status == .active { indicators.append("active") }
                    if status == .interrupted { indicators.append("interrupted") }
                    if let session = claimedBy { indicators.append("claimed:\(session)") }
                    let suffix = indicators.isEmpty ? "" : " (\(indicators.joined(separator: ", ")))"
                    return "\(job.slug)\(suffix)"
                }
                lines.append("  \(stage.name)\(typeIndicator): \(jobStrs.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func statusJSON(pipeline: String) throws -> String {
        let config = try storage.pipelineConfig(name: pipeline)
        let state = storage.pipelineState()
        let entry = state.pipelines[pipeline] ?? PipelineStateEntry()

        var stagesJSON: [[String: Any]] = []
        for stage in config.stages {
            let jobs = try storage.jobsInStage(pipeline: pipeline, stage: stage.directoryName)
            let jobsJSON: [[String: Any]] = jobs.map { job in
                var dict: [String: Any] = [
                    "slug": job.slug,
                    "title": job.title,
                    "status": (entry.jobStatuses[job.slug] ?? .queued).rawValue
                ]
                if let priority = job.priority { dict["priority"] = priority }
                if !job.labels.isEmpty { dict["labels"] = job.labels }
                if let claimedBy = entry.claims.first(where: { $0.value == job.slug })?.key {
                    dict["claimed_by"] = claimedBy
                }
                return dict
            }
            stagesJSON.append([
                "name": stage.name,
                "type": stage.type.rawValue,
                "jobs": jobsJSON
            ])
        }

        let result: [String: Any] = [
            "pipeline": pipeline,
            "paused": entry.paused,
            "stages": stagesJSON
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func statusContext() throws -> String {
        let pipelines = storage.listPipelines()
        if pipelines.isEmpty { return "" }

        var lines: [String] = ["## Pipelines in this repo", ""]

        for name in pipelines {
            let config = try storage.pipelineConfig(name: name)
            let state = storage.pipelineState()
            let entry = state.pipelines[name] ?? PipelineStateEntry()
            let totalJobs = try storage.allJobs(pipeline: name).count
            lines.append("### \(name) (\(totalJobs) jobs)")

            for stage in config.stages {
                let jobs = try storage.jobsInStage(pipeline: name, stage: stage.directoryName)
                if jobs.isEmpty {
                    lines.append("- \(stage.name): (empty)")
                } else {
                    let jobStrs = jobs.map { job in
                        let status = entry.jobStatuses[job.slug] ?? .queued
                        let claimedBy = entry.claims.first(where: { $0.value == job.slug })?.key
                        var suffix = ""
                        if status == .active { suffix += " (active" }
                        if claimedBy != nil { suffix += suffix.isEmpty ? " (claimed" : ", claimed" }
                        if !suffix.isEmpty { suffix += ")" }
                        return job.slug + suffix
                    }
                    lines.append("- \(stage.name): \(jobStrs.joined(separator: ", "))")
                }
            }
            lines.append("")
        }

        lines.append("### CLI quick reference")
        lines.append("- `hootty pipeline claim [--job <slug>]` — claim a task (auto-picks next queued if no slug)")
        lines.append("- `hootty pipeline release` — release your current claim")
        lines.append("- `hootty pipeline status` — show current board state")
        lines.append("- `hootty pipeline log <message>` — log progress on your active task")
        lines.append("- `hootty pipeline advance` — move your task to the next stage")
        return lines.joined(separator: "\n")
    }

    // MARK: - Add Job

    public func addJob(pipeline: String?, title: String, body: String?, stage: String?) throws -> Job {
        let pipelineName = try resolveDefaultPipeline(pipeline)

        return try storage.withStateLock {
            let config = try storage.pipelineConfig(name: pipelineName)

            // Determine target stage
            let targetStage: Stage
            if let stageName = stage {
                guard let found = config.stages.first(where: {
                    $0.directoryName == stageName.lowercased() || $0.name.lowercased() == stageName.lowercased()
                }) else {
                    throw PipelineError.stageNotFound(stageName)
                }
                targetStage = found
            } else {
                guard let first = config.stages.first else {
                    throw PipelineError.invalidConfig("Pipeline has no stages")
                }
                targetStage = first
            }

            // Auto-number
            let number = try storage.nextJobNumber(pipeline: pipelineName)
            let slug = deriveSlug(from: title)
            let paddedNum = String(format: "%03d", number)
            let filename = "\(paddedNum)-\(slug).md"

            // Create job content
            let now = ISO8601DateFormatter().string(from: Date())
            let jobBody = body ?? ""
            let content = serializeJob(title: title, created: now, body: jobBody)

            try storage.writeJob(
                pipeline: pipelineName,
                stage: targetStage.directoryName,
                filename: filename,
                content: content
            )

            // Set initial status
            var state = storage.pipelineState()
            if state.pipelines[pipelineName] == nil {
                state.pipelines[pipelineName] = PipelineStateEntry()
            }
            state.pipelines[pipelineName]!.jobStatuses["\(paddedNum)-\(slug)"] = .queued
            try storage.savePipelineState(state)

            // Append log
            try storage.appendLog(
                pipeline: pipelineName,
                stage: targetStage.directoryName,
                filename: filename,
                message: "Created in \(targetStage.name)"
            )

            return Job(
                filename: filename,
                slug: "\(paddedNum)-\(slug)",
                number: number,
                title: title,
                created: now,
                stage: targetStage.directoryName
            )
        }
    }

    // MARK: - Move Job

    public func moveJob(slug: String, toStage: String, pipeline: String?) throws -> Job {
        let pipelineName = try resolveDefaultPipeline(pipeline)

        return try storage.withStateLock {
            let config = try storage.pipelineConfig(name: pipelineName)

            guard let (fromStage, job) = try storage.findJob(pipeline: pipelineName, slug: slug) else {
                throw PipelineError.jobNotFound(slug)
            }

            guard let targetStage = config.stages.first(where: {
                $0.directoryName == toStage.lowercased() || $0.name.lowercased() == toStage.lowercased()
            }) else {
                throw PipelineError.stageNotFound(toStage)
            }

            try storage.moveJobFile(
                pipeline: pipelineName,
                filename: job.filename,
                fromStage: fromStage,
                toStage: targetStage.directoryName
            )

            try storage.appendLog(
                pipeline: pipelineName,
                stage: targetStage.directoryName,
                filename: job.filename,
                message: "Moved from \(fromStage) to \(targetStage.name)"
            )

            var updated = job
            updated.stage = targetStage.directoryName
            return updated
        }
    }

    // MARK: - Remove Job

    public func removeJob(slug: String, pipeline: String?) throws {
        let pipelineName = try resolveDefaultPipeline(pipeline)

        try storage.withStateLock {
            guard let (stage, job) = try storage.findJob(pipeline: pipelineName, slug: slug) else {
                throw PipelineError.jobNotFound(slug)
            }

            // Release any claim on this job
            var state = storage.pipelineState()
            if var entry = state.pipelines[pipelineName] {
                let claimKeys = entry.claims.filter { $0.value == slug }.map(\.key)
                for key in claimKeys {
                    entry.claims.removeValue(forKey: key)
                }
                entry.jobStatuses.removeValue(forKey: slug)
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)
            }

            try storage.appendLog(
                pipeline: pipelineName,
                stage: stage,
                filename: job.filename,
                message: "Removed by user"
            )

            try storage.deleteJobFile(pipeline: pipelineName, stage: stage, filename: job.filename)
        }
    }

    // MARK: - Archive

    public func archiveJobs(pipeline: String?) throws -> Int {
        let pipelineName = try resolveDefaultPipeline(pipeline)
        let config = try storage.pipelineConfig(name: pipelineName)

        guard let lastStage = config.stages.last else { return 0 }

        let jobs = try storage.jobsInStage(pipeline: pipelineName, stage: lastStage.directoryName)
        if jobs.isEmpty { return 0 }

        let archiveDir = "archive"
        for job in jobs {
            try storage.moveJobFile(
                pipeline: pipelineName,
                filename: job.filename,
                fromStage: lastStage.directoryName,
                toStage: archiveDir
            )
        }

        // Clean up statuses
        try storage.withStateLock {
            var state = storage.pipelineState()
            if var entry = state.pipelines[pipelineName] {
                for job in jobs {
                    entry.jobStatuses.removeValue(forKey: job.slug)
                }
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)
            }
        }

        return jobs.count
    }

    // MARK: - Log

    public func logMessage(_ message: String) throws {
        let (pipelineName, job) = try findCurrentClaim()
        let (stage, _) = try findJobOrThrow(pipeline: pipelineName, slug: job)

        try storage.appendLog(
            pipeline: pipelineName,
            stage: stage,
            filename: "\(job).md",
            message: message
        )
    }

    // MARK: - Claim

    public func claim(pipeline: String?, jobSlug: String?, stage: String?,
                      force: Bool, worktree: Bool, formatContext: Bool) throws -> ClaimResult {
        let pipelineName = try resolveDefaultPipeline(pipeline)

        return try storage.withStateLock {
            var state = storage.pipelineState()
            if state.pipelines[pipelineName] == nil {
                state.pipelines[pipelineName] = PipelineStateEntry()
            }
            var entry = state.pipelines[pipelineName]!

            // Check if paused
            if entry.paused {
                throw PipelineError.pipelinePaused
            }

            // Reap stale claims
            reapStaleClaims(entry: &entry)

            // Check for existing claim (unless force)
            if let existingSlug = entry.claims[sessionID], !force {
                return .alreadyClaimed(currentJob: existingSlug, pipeline: pipelineName)
            }

            // Check max_claims
            let config = try storage.pipelineConfig(name: pipelineName)
            if let max = config.settings.maxClaims, entry.claims.count >= max, !force {
                throw PipelineError.noJobsAvailable(pipelineName)
            }

            // Find job to claim
            let targetJob: Job
            let targetStage: String

            if let slug = jobSlug {
                // Claim specific job
                guard let (foundStage, job) = try storage.findJob(pipeline: pipelineName, slug: slug) else {
                    throw PipelineError.jobNotFound(slug)
                }
                // Check if already claimed by someone else
                if let claimedBy = entry.claims.first(where: { $0.value == slug })?.key,
                   claimedBy != sessionID, !force {
                    throw PipelineError.alreadyClaimed(slug)
                }
                targetJob = job
                targetStage = foundStage
            } else if let stageName = stage {
                // Claim from specific stage
                guard let stageConfig = config.stages.first(where: {
                    $0.directoryName == stageName.lowercased() || $0.name.lowercased() == stageName.lowercased()
                }) else {
                    throw PipelineError.stageNotFound(stageName)
                }
                let jobs = try storage.jobsInStage(pipeline: pipelineName, stage: stageConfig.directoryName)
                let claimedSlugs = Set(entry.claims.values)
                guard let job = jobs.first(where: { !claimedSlugs.contains($0.slug) }) else {
                    return .noJobsAvailable(pipeline: pipelineName)
                }
                targetJob = job
                targetStage = stageConfig.directoryName
            } else {
                // Auto-claim: interrupted first, then queued by stage order
                guard let (foundStage, job) = try findClaimableJob(
                    pipeline: pipelineName, config: config, entry: entry
                ) else {
                    return .noJobsAvailable(pipeline: pipelineName)
                }
                targetJob = job
                targetStage = foundStage
            }

            // Record claim
            entry.claims[sessionID] = targetJob.slug
            entry.jobStatuses[targetJob.slug] = .active
            state.pipelines[pipelineName] = entry
            try storage.savePipelineState(state)

            // Append log
            try storage.appendLog(
                pipeline: pipelineName,
                stage: targetStage,
                filename: targetJob.filename,
                message: "Claimed by \(sessionID)"
            )

            // Resolve prompt
            let stageConfig = config.stages.first(where: { $0.directoryName == targetStage })
            let prompt: String? = if let cmd = stageConfig?.command {
                resolveVariables(cmd, job: targetJob, pipeline: pipelineName, stage: targetStage, config: config)
            } else {
                targetJob.prompt.isEmpty ? nil : resolveVariables(targetJob.prompt, job: targetJob, pipeline: pipelineName, stage: targetStage, config: config)
            }

            // Handle worktree creation
            if worktree {
                try createWorktree(for: targetJob, pipeline: pipelineName)
            }

            if formatContext {
                let contextOutput = try buildClaimContext(
                    job: targetJob, pipeline: pipelineName, stage: targetStage, config: config
                )
                var contextJob = targetJob
                contextJob.prompt = contextOutput
                return .claimed(job: contextJob, pipeline: pipelineName, prompt: contextOutput)
            }

            return .claimed(job: targetJob, pipeline: pipelineName, prompt: prompt)
        }
    }

    // MARK: - Advance

    public func advance() throws -> AdvanceResult {
        try storage.withStateLock {
            var state = storage.pipelineState()

            // Find which pipeline this session has a claim in
            guard let (pipelineName, slug) = findClaimInState(state) else {
                return .noClaim
            }

            var entry = state.pipelines[pipelineName]!

            if entry.paused {
                return .paused
            }

            let config = try storage.pipelineConfig(name: pipelineName)

            // Find the job
            guard let (currentStage, job) = try storage.findJob(pipeline: pipelineName, slug: slug) else {
                // Job was removed/moved externally
                entry.claims.removeValue(forKey: sessionID)
                entry.jobStatuses.removeValue(forKey: slug)
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)
                return .noClaim
            }

            // Find current stage index
            guard let currentIdx = config.stages.firstIndex(where: { $0.directoryName == currentStage }) else {
                throw PipelineError.stageNotFound(currentStage)
            }

            let nextIdx = currentIdx + 1

            // No next stage → completed
            if nextIdx >= config.stages.count {
                entry.jobStatuses[slug] = .completed
                entry.claims.removeValue(forKey: sessionID)
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)

                try storage.appendLog(
                    pipeline: pipelineName,
                    stage: currentStage,
                    filename: job.filename,
                    message: "Completed"
                )

                return .completed(job: job, pipeline: pipelineName, fromStage: config.stages[currentIdx].name)
            }

            let nextStage = config.stages[nextIdx]

            // Move job file
            try storage.moveJobFile(
                pipeline: pipelineName,
                filename: job.filename,
                fromStage: currentStage,
                toStage: nextStage.directoryName
            )

            try storage.appendLog(
                pipeline: pipelineName,
                stage: nextStage.directoryName,
                filename: job.filename,
                message: "Advanced to \(nextStage.name)"
            )

            if nextStage.type == .automated {
                // Keep claim, set active
                entry.jobStatuses[slug] = .active
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)

                // Resolve prompt
                let prompt: String? = if let cmd = nextStage.command {
                    resolveVariables(cmd, job: job, pipeline: pipelineName, stage: nextStage.directoryName, config: config)
                } else {
                    job.prompt.isEmpty ? nil : resolveVariables(job.prompt, job: job, pipeline: pipelineName, stage: nextStage.directoryName, config: config)
                }

                return .advanced(
                    job: job, pipeline: pipelineName,
                    fromStage: config.stages[currentIdx].name,
                    toStage: nextStage.name,
                    nextPrompt: prompt
                )
            } else {
                // Manual stage: release claim, set interrupted
                entry.jobStatuses[slug] = .interrupted
                entry.claims.removeValue(forKey: sessionID)
                state.pipelines[pipelineName] = entry
                try storage.savePipelineState(state)

                return .manual(
                    job: job, pipeline: pipelineName,
                    fromStage: config.stages[currentIdx].name,
                    toStage: nextStage.name
                )
            }
        }
    }

    // MARK: - Release

    public func release() throws {
        try storage.withStateLock {
            var state = storage.pipelineState()

            guard let (pipelineName, slug) = findClaimInState(state) else {
                throw PipelineError.noClaim
            }

            var entry = state.pipelines[pipelineName]!
            entry.claims.removeValue(forKey: sessionID)
            entry.jobStatuses[slug] = .interrupted
            state.pipelines[pipelineName] = entry
            try storage.savePipelineState(state)

            // Find job to append log
            if let (stage, job) = try storage.findJob(pipeline: pipelineName, slug: slug) {
                try storage.appendLog(
                    pipeline: pipelineName,
                    stage: stage,
                    filename: job.filename,
                    message: "Released by \(sessionID)"
                )
            }
        }
    }

    // MARK: - Current Job

    public func currentJob(formatContext: Bool) throws -> String {
        let state = storage.pipelineState()

        guard let (pipelineName, slug) = findClaimInState(state) else {
            return "No active claim."
        }

        guard let (stage, job) = try storage.findJob(pipeline: pipelineName, slug: slug) else {
            return "Claimed job \(slug) not found (may have been removed)."
        }

        if formatContext {
            let config = try storage.pipelineConfig(name: pipelineName)
            return try buildClaimContext(job: job, pipeline: pipelineName, stage: stage, config: config)
        }

        let entry = state.pipelines[pipelineName] ?? PipelineStateEntry()
        let status = entry.jobStatuses[slug] ?? .queued
        return "Pipeline: \(pipelineName)\nJob: \(job.title) (\(job.slug))\nStage: \(stage)\nStatus: \(status.rawValue)"
    }

    // MARK: - Whoami

    public func whoami() -> String {
        let state = storage.pipelineState()
        var lines = ["Session: \(sessionID)"]

        for (pipelineName, entry) in state.pipelines {
            if let slug = entry.claims[sessionID] {
                lines.append("Claim: \(slug) in pipeline \"\(pipelineName)\"")
            }
        }

        if lines.count == 1 {
            lines.append("No active claims.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Reap

    public func reap() -> [String] {
        var reaped: [String] = []
        do {
            try storage.withStateLock {
                var state = storage.pipelineState()
                for (pipelineName, var entry) in state.pipelines {
                    let staleKeys = entry.claims.keys.filter { !isSessionAlive($0) }
                    for key in staleKeys {
                        if let slug = entry.claims[key] {
                            entry.jobStatuses[slug] = .interrupted
                            reaped.append("\(key) → \(slug)")
                        }
                        entry.claims.removeValue(forKey: key)
                    }
                    state.pipelines[pipelineName] = entry
                }
                try storage.savePipelineState(state)
            }
        } catch {
            // Silently fail on reap errors
        }
        return reaped
    }

    // MARK: - Play / Pause

    public func play(pipeline: String?) throws {
        let pipelineName = try resolveDefaultPipeline(pipeline)
        try storage.withStateLock {
            var state = storage.pipelineState()
            if state.pipelines[pipelineName] == nil {
                state.pipelines[pipelineName] = PipelineStateEntry()
            }
            state.pipelines[pipelineName]!.paused = false
            try storage.savePipelineState(state)
        }
    }

    public func pause(pipeline: String?) throws {
        let pipelineName = try resolveDefaultPipeline(pipeline)
        try storage.withStateLock {
            var state = storage.pipelineState()
            if state.pipelines[pipelineName] == nil {
                state.pipelines[pipelineName] = PipelineStateEntry()
            }
            state.pipelines[pipelineName]!.paused = true
            try storage.savePipelineState(state)
        }
    }

    // MARK: - Stage Management

    public func addStage(pipeline: String?, name: String, type: StageType, after: String?) throws {
        let pipelineName = try resolveDefaultPipeline(pipeline)
        var config = try storage.pipelineConfig(name: pipelineName)

        let newStage = Stage(name: name, type: type)

        if let afterName = after {
            guard let idx = config.stages.firstIndex(where: {
                $0.directoryName == afterName.lowercased() || $0.name.lowercased() == afterName.lowercased()
            }) else {
                throw PipelineError.stageNotFound(afterName)
            }
            config.stages.insert(newStage, at: idx + 1)
        } else {
            // Insert before the last stage (Done)
            if config.stages.count > 1 {
                config.stages.insert(newStage, at: config.stages.count - 1)
            } else {
                config.stages.append(newStage)
            }
        }

        try storage.savePipelineConfig(name: pipelineName, config: config)

        // Create stage directory
        let stageDir = storage.pipelineDir(name: pipelineName).appendingPathComponent(newStage.directoryName)
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
    }

    public func removeStage(pipeline: String?, name: String) throws {
        let pipelineName = try resolveDefaultPipeline(pipeline)
        var config = try storage.pipelineConfig(name: pipelineName)

        guard let idx = config.stages.firstIndex(where: {
            $0.directoryName == name.lowercased() || $0.name.lowercased() == name.lowercased()
        }) else {
            throw PipelineError.stageNotFound(name)
        }

        let removedStage = config.stages[idx]

        // Move jobs to previous stage (or first stage if removing the first)
        let targetIdx = idx > 0 ? idx - 1 : (config.stages.count > 1 ? 1 : -1)
        if targetIdx >= 0 {
            let targetStage = config.stages[targetIdx]
            let jobs = try storage.jobsInStage(pipeline: pipelineName, stage: removedStage.directoryName)
            for job in jobs {
                try storage.moveJobFile(
                    pipeline: pipelineName,
                    filename: job.filename,
                    fromStage: removedStage.directoryName,
                    toStage: targetStage.directoryName
                )
            }
        }

        config.stages.remove(at: idx)
        try storage.savePipelineConfig(name: pipelineName, config: config)
    }

    public func moveStage(pipeline: String?, name: String, after: String) throws {
        let pipelineName = try resolveDefaultPipeline(pipeline)
        var config = try storage.pipelineConfig(name: pipelineName)

        guard let fromIdx = config.stages.firstIndex(where: {
            $0.directoryName == name.lowercased() || $0.name.lowercased() == name.lowercased()
        }) else {
            throw PipelineError.stageNotFound(name)
        }

        guard let afterIdx = config.stages.firstIndex(where: {
            $0.directoryName == after.lowercased() || $0.name.lowercased() == after.lowercased()
        }) else {
            throw PipelineError.stageNotFound(after)
        }

        let stage = config.stages.remove(at: fromIdx)
        let insertIdx = afterIdx >= fromIdx ? afterIdx : afterIdx + 1
        config.stages.insert(stage, at: insertIdx)

        try storage.savePipelineConfig(name: pipelineName, config: config)
    }

    // MARK: - Helpers

    public func resolveDefaultPipeline(_ explicit: String?) throws -> String {
        if let name = explicit { return name }
        let config = storage.repoConfig()
        let name = config.defaultPipeline
        guard storage.pipelineExists(name) else {
            // If default doesn't exist, try the first available
            let pipelines = storage.listPipelines()
            guard let first = pipelines.first else {
                throw PipelineError.noPipelineDirectory
            }
            return first
        }
        return name
    }

    /// Find a claimable job: interrupted first, then queued by stage order
    private func findClaimableJob(pipeline: String, config: PipelineConfig,
                                  entry: PipelineStateEntry) throws -> (String, Job)? {
        let claimedSlugs = Set(entry.claims.values)

        // 1. Interrupted jobs first
        for stage in config.stages {
            let jobs = try storage.jobsInStage(pipeline: pipeline, stage: stage.directoryName)
            for job in jobs {
                let status = entry.jobStatuses[job.slug] ?? .queued
                if status == .interrupted, !claimedSlugs.contains(job.slug) {
                    return (stage.directoryName, job)
                }
            }
        }

        // 2. Queued jobs by stage order
        for stage in config.stages {
            let jobs = try storage.jobsInStage(pipeline: pipeline, stage: stage.directoryName)
            for job in jobs {
                let status = entry.jobStatuses[job.slug] ?? .queued
                if status == .queued, !claimedSlugs.contains(job.slug) {
                    return (stage.directoryName, job)
                }
            }
        }

        return nil
    }

    /// Find which pipeline and job this session has a claim in
    private func findClaimInState(_ state: PipelineState) -> (String, String)? {
        for (pipelineName, entry) in state.pipelines {
            if let slug = entry.claims[sessionID] {
                return (pipelineName, slug)
            }
        }
        return nil
    }

    /// Find the current claim or throw
    private func findCurrentClaim() throws -> (String, String) {
        let state = storage.pipelineState()
        guard let result = findClaimInState(state) else {
            throw PipelineError.noClaim
        }
        return result
    }

    /// Find a job or throw
    private func findJobOrThrow(pipeline: String, slug: String) throws -> (String, Job) {
        guard let result = try storage.findJob(pipeline: pipeline, slug: slug) else {
            throw PipelineError.jobNotFound(slug)
        }
        return result
    }

    /// Reap stale claims (in-place)
    private func reapStaleClaims(entry: inout PipelineStateEntry) {
        let staleKeys = entry.claims.keys.filter { !isSessionAlive($0) }
        for key in staleKeys {
            if let slug = entry.claims[key] {
                entry.jobStatuses[slug] = .interrupted
            }
            entry.claims.removeValue(forKey: key)
        }
    }

    /// Check if a session is still alive (PID-based check)
    private func isSessionAlive(_ sessionID: String) -> Bool {
        // If it looks like a PID, check with kill -0
        if let pid = Int32(sessionID) {
            return kill(pid, 0) == 0
        }
        // For non-PID session IDs, assume alive (manual reap needed)
        return true
    }

    /// Resolve {{variable}} placeholders in a string
    private func resolveVariables(_ template: String, job: Job, pipeline: String,
                                  stage: String, config: PipelineConfig) -> String {
        var result = template

        // Built-in variables
        result = result.replacingOccurrences(of: "{{job}}", with: job.slug)
        result = result.replacingOccurrences(of: "{{stage}}", with: stage)
        result = result.replacingOccurrences(of: "{{pipeline}}", with: pipeline)
        if let repoRoot = try? PipelineStorage.canonicalRepoRoot() {
            result = result.replacingOccurrences(of: "{{repo}}", with: repoRoot)
        }

        // Job frontmatter
        result = result.replacingOccurrences(of: "{{title}}", with: job.title)
        if let priority = job.priority {
            result = result.replacingOccurrences(of: "{{priority}}", with: priority)
        }
        result = result.replacingOccurrences(of: "{{labels}}", with: job.labels.joined(separator: ", "))

        // Pipeline variables
        for (key, value) in config.settings.variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        // Environment variables (match remaining {{VAR}} patterns)
        let envPattern = try? NSRegularExpression(pattern: "\\{\\{([A-Z_][A-Z0-9_]*)\\}\\}", options: [])
        if let pattern = envPattern {
            let matches = pattern.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    let varName = String(result[range])
                    if let envValue = ProcessInfo.processInfo.environment[varName] {
                        if let fullRange = Range(match.range, in: result) {
                            result.replaceSubrange(fullRange, with: envValue)
                        }
                    }
                }
            }
        }

        return result
    }

    /// Build context output for --format context
    private func buildClaimContext(job: Job, pipeline: String, stage: String,
                                   config: PipelineConfig) throws -> String {
        var lines: [String] = []

        // Prepend memory.md if present
        if let memory = storage.readMemory() {
            lines.append(memory.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
            lines.append("---")
            lines.append("")
        }

        lines.append("## Pipeline: \(pipeline)")

        // Find next stage info
        let currentIdx = config.stages.firstIndex(where: { $0.directoryName == stage })
        let currentStageName = currentIdx.map { config.stages[$0].name } ?? stage
        var nextStageInfo = ""
        if let idx = currentIdx, idx + 1 < config.stages.count {
            let next = config.stages[idx + 1]
            let typeDesc = next.type == .manual ? "manual — will pause for human review" : "automated"
            nextStageInfo = "**Next stage**: \(next.name) (\(typeDesc))"
        }

        lines.append("**Claimed job**: \(job.title) (stage: \(currentStageName))")
        if !nextStageInfo.isEmpty {
            lines.append(nextStageInfo)
        }
        lines.append("")
        lines.append("### Task")

        // Include full job body (with all context sections)
        if !job.fullBody.isEmpty {
            lines.append(job.fullBody)
        } else if !job.prompt.isEmpty {
            lines.append(job.prompt)
        }

        lines.append("")
        lines.append("### Pipeline Instructions")
        lines.append("When you have completed this task, run: `hootty pipeline advance`")
        lines.append("This will move the job to the next stage. If the next stage is automated,")
        lines.append("its prompt will be printed — continue working on it. If manual, stop and")
        lines.append("wait for the user.")

        return lines.joined(separator: "\n")
    }

    /// Create a git worktree for a job
    private func createWorktree(for job: Job, pipeline _: String) throws {
        let repoRoot = try PipelineStorage.canonicalRepoRoot()
        let branchName = "pipeline/\(job.slug)"
        let worktreePath = "\(repoRoot)/.claude/worktrees/pipeline/\(job.slug)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "add", worktreePath, "-b", branchName]
        process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errPipe = process.standardError as! Pipe
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw PipelineError.gitError("Failed to create worktree: \(errStr)")
        }
    }
}

// MARK: - Session Identity

/// Resolve session identity from environment
public func resolveSessionID() -> String {
    // 1. Explicit pipeline session
    if let session = ProcessInfo.processInfo.environment["PIPELINE_SESSION"], !session.isEmpty {
        return session
    }
    // 2. Claude Code session ID
    if let claude = ProcessInfo.processInfo.environment["CLAUDE_SESSION_ID"], !claude.isEmpty {
        return claude
    }
    // 3. Parent process ID
    return ProcessInfo.processInfo.environment["PPID"] ?? String(getppid())
}
