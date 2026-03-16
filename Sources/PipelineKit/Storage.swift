import Foundation
#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// File-based storage for pipeline data.
/// All paths are relative to the `.hootty/pipeline/` directory at the canonical repo root.
public class PipelineStorage {
    public let rootPath: String // path to .hootty/pipeline/ directory

    public init(rootPath: String) {
        self.rootPath = rootPath
    }

    // MARK: - Root Discovery

    /// Find the `.hootty/pipeline/` directory by resolving the canonical git repo root.
    public static func findRoot(from workingDirectory: String? = nil) throws -> String {
        let repoRoot = try canonicalRepoRoot(from: workingDirectory)
        let hoottyDir = (repoRoot as NSString).appendingPathComponent(".hootty")
        let pipelinePath = (hoottyDir as NSString).appendingPathComponent("pipeline")
        guard FileManager.default.fileExists(atPath: pipelinePath) else {
            throw PipelineError.noPipelineDirectory
        }
        return pipelinePath
    }

    /// Resolve canonical repo root using `git rev-parse --git-common-dir`.
    public static func canonicalRepoRoot(from workingDirectory: String? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--git-common-dir"]
        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PipelineError.gitError("Not a git repository")
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Resolve to absolute path
        let url: URL
        if output.hasPrefix("/") {
            url = URL(fileURLWithPath: output)
        } else {
            let base = workingDirectory ?? FileManager.default.currentDirectoryPath
            url = URL(fileURLWithPath: base).appendingPathComponent(output)
        }

        // Parent of .git directory is repo root
        return url.deletingLastPathComponent().standardized.path
    }

    // MARK: - File Locking

    /// Execute a closure with an exclusive lock on .state.json
    @discardableResult
    public func withStateLock<T>(_ body: () throws -> T) throws -> T {
        let lockPath = (rootPath as NSString).appendingPathComponent(".state.lock")
        let fd = open(lockPath, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else { throw PipelineError.lockFailed }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw PipelineError.lockFailed }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    // MARK: - Repo Config (config.yaml)

    public func repoConfig() -> RepoConfig {
        let path = (rootPath as NSString).appendingPathComponent("config.yaml")
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return RepoConfig()
        }
        return parseRepoConfig(content)
    }

    public func saveRepoConfig(_ config: RepoConfig) throws {
        let path = (rootPath as NSString).appendingPathComponent("config.yaml")
        try serializeRepoConfig(config).write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Pipeline Config (pipeline.yaml)

    public func pipelineConfig(name: String) throws -> PipelineConfig {
        let path = pipelineDir(name: name).appendingPathComponent("pipeline.yaml")
        guard let data = FileManager.default.contents(atPath: path.path),
              let content = String(data: data, encoding: .utf8) else {
            throw PipelineError.pipelineNotFound(name)
        }
        return parsePipelineConfig(content)
    }

    public func savePipelineConfig(name: String, config: PipelineConfig) throws {
        let path = pipelineDir(name: name).appendingPathComponent("pipeline.yaml")
        try serializePipelineConfig(config).write(to: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Pipeline State (.state.json)

    public func pipelineState() -> PipelineState {
        let path = (rootPath as NSString).appendingPathComponent(".state.json")
        guard let data = FileManager.default.contents(atPath: path) else {
            return PipelineState()
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode(PipelineState.self, from: data)) ?? PipelineState()
    }

    public func savePipelineState(_ state: PipelineState) throws {
        let path = (rootPath as NSString).appendingPathComponent(".state.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // MARK: - Pipeline Discovery

    /// List all pipeline names (subdirectories of .hootty/pipeline/ that contain pipeline.yaml)
    public func listPipelines() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: rootPath) else { return [] }
        return entries.filter { entry in
            var isDir: ObjCBool = false
            let fullPath = (rootPath as NSString).appendingPathComponent(entry)
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { return false }
            let yamlPath = (fullPath as NSString).appendingPathComponent("pipeline.yaml")
            return fm.fileExists(atPath: yamlPath)
        }.sorted()
    }

    public func pipelineExists(_ name: String) -> Bool {
        let yamlPath = pipelineDir(name: name).appendingPathComponent("pipeline.yaml")
        return FileManager.default.fileExists(atPath: yamlPath.path)
    }

    // MARK: - Jobs

    /// List jobs in a specific stage of a pipeline
    public func jobsInStage(pipeline: String, stage: String) throws -> [Job] {
        let stageDir = pipelineDir(name: pipeline).appendingPathComponent(stage)
        let fm = FileManager.default
        guard fm.fileExists(atPath: stageDir.path) else { return [] }
        guard let files = try? fm.contentsOfDirectory(atPath: stageDir.path) else { return [] }

        return files
            .filter { $0.hasSuffix(".md") }
            .sorted { numericSort($0, $1) }
            .compactMap { filename in
                readJob(pipeline: pipeline, stage: stage, filename: filename)
            }
    }

    /// List all jobs across all stages in a pipeline
    public func allJobs(pipeline: String) throws -> [(stage: String, job: Job)] {
        let config = try pipelineConfig(name: pipeline)
        return try allJobs(pipeline: pipeline, config: config)
    }

    /// List all jobs using a pre-loaded config (avoids re-reading pipeline.yaml).
    public func allJobs(pipeline: String, config: PipelineConfig) throws -> [(stage: String, job: Job)] {
        var result: [(stage: String, job: Job)] = []
        for stage in config.stages {
            let jobs = try jobsInStage(pipeline: pipeline, stage: stage.directoryName)
            for job in jobs {
                result.append((stage: stage.directoryName, job: job))
            }
        }
        return result
    }

    /// Read a single job file
    public func readJob(pipeline: String, stage: String, filename: String) -> Job? {
        let path = pipelineDir(name: pipeline)
            .appendingPathComponent(stage)
            .appendingPathComponent(filename)
        guard let data = FileManager.default.contents(atPath: path.path),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let fm = parseFrontmatter(content)
        let slug = (filename as NSString).deletingPathExtension

        // Extract prompt (body up to first ## heading)
        let prompt = extractPrompt(from: fm.body)

        return Job(
            filename: filename,
            slug: slug,
            number: jobNumber(from: filename) ?? 0,
            title: fm.fields["title"] ?? slug,
            priority: fm.fields["priority"],
            labels: fm.labels,
            created: fm.fields["created"],
            prompt: prompt,
            fullBody: fm.body,
            stage: stage
        )
    }

    /// Find a job by slug across all stages
    public func findJob(pipeline: String, slug: String) throws -> (stage: String, job: Job)? {
        let config = try pipelineConfig(name: pipeline)
        for stage in config.stages {
            let jobs = try jobsInStage(pipeline: pipeline, stage: stage.directoryName)
            if let job = jobs.first(where: { $0.slug == slug }) {
                return (stage: stage.directoryName, job: job)
            }
        }
        return nil
    }

    /// Write a job file
    public func writeJob(pipeline: String, stage: String, filename: String, content: String) throws {
        let dir = pipelineDir(name: pipeline).appendingPathComponent(stage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(filename)
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    /// Move a job file between stages
    public func moveJobFile(pipeline: String, filename: String, fromStage: String, toStage: String) throws {
        let from = pipelineDir(name: pipeline)
            .appendingPathComponent(fromStage)
            .appendingPathComponent(filename)
        let toDir = pipelineDir(name: pipeline).appendingPathComponent(toStage)
        try FileManager.default.createDirectory(at: toDir, withIntermediateDirectories: true)
        let to = toDir.appendingPathComponent(filename)
        try FileManager.default.moveItem(at: from, to: to)
    }

    /// Delete a job file
    public func deleteJobFile(pipeline: String, stage: String, filename: String) throws {
        let path = pipelineDir(name: pipeline)
            .appendingPathComponent(stage)
            .appendingPathComponent(filename)
        try FileManager.default.removeItem(at: path)
    }

    /// Append a log entry to a job file's ## Log section
    public func appendLog(pipeline: String, stage: String, filename: String, message: String) throws {
        let path = pipelineDir(name: pipeline)
            .appendingPathComponent(stage)
            .appendingPathComponent(filename)
        guard var content = try? String(contentsOf: path, encoding: .utf8) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "- \(timestamp) — \(message)"

        if content.contains("## Log") {
            content += "\n\(logEntry)"
        } else {
            content += "\n\n## Log\n\n\(logEntry)"
        }

        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    /// Get the next available job number across all stages
    public func nextJobNumber(pipeline: String) throws -> Int {
        let allJobs = try allJobs(pipeline: pipeline)
        let maxNum = allJobs.map(\.job.number).max() ?? -1
        return maxNum + 1
    }

    // MARK: - Pipeline Creation / Deletion

    public func createPipeline(name: String, config: PipelineConfig) throws {
        let dir = pipelineDir(name: name)
        let fm = FileManager.default

        guard !fm.fileExists(atPath: dir.path) else {
            throw PipelineError.pipelineAlreadyExists(name)
        }

        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write pipeline.yaml
        try savePipelineConfig(name: name, config: config)

        // Create stage directories
        for stage in config.stages {
            let stageDir = dir.appendingPathComponent(stage.directoryName)
            try fm.createDirectory(at: stageDir, withIntermediateDirectories: true)
        }
    }

    public func deletePipeline(name: String) throws {
        let dir = pipelineDir(name: name)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw PipelineError.pipelineNotFound(name)
        }
        try FileManager.default.removeItem(at: dir)
    }

    // MARK: - Memory

    public func readMemory() -> String? {
        let path = (rootPath as NSString).appendingPathComponent("memory.md")
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - Init Root

    /// Create the .hootty/pipeline/ directory and config.yaml
    public func initRoot(defaultPipeline: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: rootPath, withIntermediateDirectories: true)

        // Create config.yaml
        try saveRepoConfig(RepoConfig(defaultPipeline: defaultPipeline))

        // Add .state.json and .state.lock to .gitignore
        let gitignorePath = (rootPath as NSString).appendingPathComponent(".gitignore")
        let gitignoreContent = ".state.json\n.state.lock\npipeline.sock\n.daemon.pid\n.daemon.log\n"
        if !fm.fileExists(atPath: gitignorePath) {
            try gitignoreContent.write(toFile: gitignorePath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Job File Path

    public func jobFilePath(pipeline: String, stage: String, filename: String) -> URL {
        pipelineDir(name: pipeline)
            .appendingPathComponent(stage)
            .appendingPathComponent(filename)
    }

    // MARK: - Helpers

    func pipelineDir(name: String) -> URL {
        URL(fileURLWithPath: rootPath).appendingPathComponent(name)
    }
}

// MARK: - Private Helpers

/// Extract the prompt from the body (text up to first ## heading)
private func extractPrompt(from body: String) -> String {
    let lines = body.components(separatedBy: "\n")
    var promptLines: [String] = []
    for line in lines {
        if line.hasPrefix("## ") { break }
        promptLines.append(line)
    }
    return promptLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Numeric-aware filename sort: "001-foo.md" < "002-bar.md" < "010-baz.md"
private func numericSort(_ a: String, _ b: String) -> Bool {
    let numA = jobNumber(from: a) ?? Int.max
    let numB = jobNumber(from: b) ?? Int.max
    return numA < numB
}
