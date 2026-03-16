import Foundation
#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Pipeline daemon: watches files, serves events over Unix socket, handles auto-execution.
public class PipelineDaemon {
    public let storage: PipelineStorage
    private let engine: PipelineEngine
    private let server: SocketServer
    private let watcher: FileWatcher
    private var lastSnapshot: BoardSnapshot
    private var selfChangeDeadline: Date = .distantPast
    private let stateQueue = DispatchQueue(label: "pipeline.daemon.state")

    /// Runners bound for auto-execution. Maps pane ID → session ID.
    private var runners: [String: String] = [:]

    public init(storage: PipelineStorage) {
        self.storage = storage
        self.engine = PipelineEngine(storage: storage, sessionID: "daemon")
        self.server = SocketServer(socketPath: storage.socketPath)
        self.watcher = FileWatcher(path: storage.rootPath)
        self.lastSnapshot = BoardSnapshot()
    }

    // MARK: - Lifecycle

    /// Run the daemon (blocks forever until signaled).
    public func run() throws {
        // Write PID
        try storage.writeDaemonPID(getpid())

        // Take initial snapshot
        lastSnapshot = takeSnapshot()

        // Start socket server
        server.onCommand = { [weak self] command, clientFD in
            self?.handleCommand(command, from: clientFD)
        }
        try server.start()

        // Start file watcher
        watcher.start { [weak self] paths in
            self?.onFileChange(paths)
        }

        // Set up signal handlers
        setupSignalHandlers()

        // Log startup
        logDaemon("Daemon started (PID: \(getpid()), socket: \(storage.socketPath))")

        // Run forever
        dispatchMain()
    }

    /// Clean shutdown
    public func shutdown() {
        logDaemon("Daemon shutting down")
        watcher.stop()
        server.stop()
        storage.removeDaemonPID()
        exit(0)
    }

    // MARK: - Signal Handlers

    private func setupSignalHandlers() {
        // SIGTERM
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigtermSource.setEventHandler { [weak self] in
            self?.shutdown()
        }
        sigtermSource.resume()
        signal(SIGTERM, SIG_IGN)

        // SIGINT
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSource.setEventHandler { [weak self] in
            self?.shutdown()
        }
        sigintSource.resume()
        signal(SIGINT, SIG_IGN)
    }

    // MARK: - File Change Detection

    private func onFileChange(_: [String]) {
        // Ignore events from our own changes (debounce window)
        if Date() < selfChangeDeadline { return }

        stateQueue.async { [weak self] in
            self?.detectAndBroadcastChanges()
        }
    }

    private func detectAndBroadcastChanges() {
        let newSnapshot = takeSnapshot()
        let events = diffSnapshots(old: lastSnapshot, new: newSnapshot)
        lastSnapshot = newSnapshot

        for event in events {
            server.broadcast(event)
            logDaemon("Event: \(event.event) job=\(event.job ?? "-") pipeline=\(event.pipeline ?? "-")")
        }
    }

    /// Suppress file watcher events for a brief window after self-changes
    private func markSelfChange() {
        selfChangeDeadline = Date().addingTimeInterval(1.0)
    }

    // MARK: - Command Handling

    private func handleCommand(_ command: DaemonCommand, from clientFD: Int32) {
        stateQueue.async { [weak self] in
            self?.processCommand(command, from: clientFD)
        }
    }

    private func processCommand(_ command: DaemonCommand, from clientFD: Int32) {
        do {
            switch command.command {
            case "advance":
                try handleAdvance(command, from: clientFD)

            case "claim":
                try handleClaim(command, from: clientFD)

            case "release":
                try handleRelease(command, from: clientFD)

            case "add_job":
                try handleAddJob(command, from: clientFD)

            case "pause":
                try handlePause(command, from: clientFD)

            case "play":
                try handlePlay(command, from: clientFD)

            case "move":
                try handleMove(command, from: clientFD)

            case "bind_runner":
                handleBindRunner(command, from: clientFD)

            case "unbind_runner":
                handleUnbindRunner(command, from: clientFD)

            case "idle":
                try handleIdle(command, from: clientFD)

            case "status":
                try handleStatus(command, from: clientFD)

            default:
                server.send(DaemonResponse(success: false, message: "Unknown command: \(command.command)"),
                            to: clientFD)
            }
        } catch {
            server.send(DaemonResponse(success: false, message: error.localizedDescription),
                        to: clientFD)
            server.broadcast(.error(pipeline: command.pipeline, job: command.job, message: error.localizedDescription))
        }
    }

    // MARK: - Individual Command Handlers

    private func handleAdvance(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        let sessionEngine = PipelineEngine(storage: storage, sessionID: cmd.sessionID ?? "daemon")
        markSelfChange()
        let result = try sessionEngine.advance()

        switch result {
        case let .advanced(job, pipeline, from, to, prompt):
            server.send(DaemonResponse(success: true, message: "Advanced to \(to)"), to: clientFD)
            server.broadcast(.jobMoved(pipeline: pipeline, job: job.slug, from: from, to: to))
            server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .active))

            // If there's an injection target, send inject event
            if let prompt, let paneID = injectionTarget(for: pipeline) {
                server.broadcast(.inject(paneID: paneID, prompt: prompt, job: job.slug))
            }

        case let .manual(job, pipeline, from, to):
            server.send(DaemonResponse(success: true, message: "Waiting for human at \(to)"), to: clientFD)
            server.broadcast(.jobMoved(pipeline: pipeline, job: job.slug, from: from, to: to))
            server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .interrupted))

        case let .completed(job, pipeline, _):
            server.send(DaemonResponse(success: true, message: "Job completed"), to: clientFD)
            server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .completed))

        case .noClaim:
            server.send(DaemonResponse(success: false, message: "No active claim"), to: clientFD)

        case .paused:
            server.send(DaemonResponse(success: false, message: "Pipeline is paused"), to: clientFD)
        }

        lastSnapshot = takeSnapshot()
    }

    private func handleClaim(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        let sessionEngine = PipelineEngine(storage: storage, sessionID: cmd.sessionID ?? "daemon")
        markSelfChange()
        let result = try sessionEngine.claim(
            pipeline: cmd.pipeline, jobSlug: cmd.job, stage: cmd.stage,
            force: false, worktree: false, formatContext: false
        )

        switch result {
        case let .claimed(job, pipeline, _):
            server.send(DaemonResponse(success: true, message: "Claimed \(job.slug)"), to: clientFD)
            server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .active))

        case let .noJobsAvailable(pipeline):
            server.send(DaemonResponse(success: false, message: "No jobs available in \(pipeline)"), to: clientFD)

        case let .alreadyClaimed(job, _):
            server.send(DaemonResponse(success: false, message: "Already claimed \(job)"), to: clientFD)
        }

        lastSnapshot = takeSnapshot()
    }

    private func handleRelease(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        let sessionEngine = PipelineEngine(storage: storage, sessionID: cmd.sessionID ?? "daemon")
        markSelfChange()
        try sessionEngine.release()
        server.send(DaemonResponse(success: true, message: "Claim released"), to: clientFD)
        lastSnapshot = takeSnapshot()
    }

    private func handleAddJob(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        guard let title = cmd.title else {
            server.send(DaemonResponse(success: false, message: "Missing title"), to: clientFD)
            return
        }
        markSelfChange()
        let job = try engine.addJob(pipeline: cmd.pipeline, title: title, body: cmd.prompt, stage: cmd.stage)
        server.send(DaemonResponse(success: true, message: "Added \(job.slug)"), to: clientFD)
        try server.broadcast(.jobAdded(pipeline: engine.resolveDefaultPipeline(cmd.pipeline),
                                       job: job.slug, stage: job.stage))
        lastSnapshot = takeSnapshot()
    }

    private func handlePause(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        markSelfChange()
        try engine.pause(pipeline: cmd.pipeline)
        let pipeline = try engine.resolveDefaultPipeline(cmd.pipeline)
        server.send(DaemonResponse(success: true, message: "Paused"), to: clientFD)
        server.broadcast(.pipelinePaused(pipeline: pipeline))
        lastSnapshot = takeSnapshot()
    }

    private func handlePlay(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        markSelfChange()
        try engine.play(pipeline: cmd.pipeline)
        let pipeline = try engine.resolveDefaultPipeline(cmd.pipeline)
        server.send(DaemonResponse(success: true, message: "Resumed"), to: clientFD)
        server.broadcast(.pipelineResumed(pipeline: pipeline))
        lastSnapshot = takeSnapshot()
    }

    private func handleMove(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        guard let job = cmd.job, let stage = cmd.stage else {
            server.send(DaemonResponse(success: false, message: "Missing job or stage"), to: clientFD)
            return
        }
        markSelfChange()
        let moved = try engine.moveJob(slug: job, toStage: stage, pipeline: cmd.pipeline)
        server.send(DaemonResponse(success: true, message: "Moved to \(moved.stage)"), to: clientFD)
        lastSnapshot = takeSnapshot()
    }

    private func handleBindRunner(_ cmd: DaemonCommand, from clientFD: Int32) {
        guard let paneID = cmd.paneID ?? cmd.id else {
            server.send(DaemonResponse(success: false, message: "Missing pane_id"), to: clientFD)
            return
        }
        runners[paneID] = cmd.sessionID ?? "daemon"

        // Store injection target in state
        if let pipeline = cmd.pipeline {
            do {
                try storage.withStateLock {
                    var state = storage.pipelineState()
                    if state.pipelines[pipeline] == nil {
                        state.pipelines[pipeline] = PipelineStateEntry()
                    }
                    state.pipelines[pipeline]?.injectionTarget = paneID
                    try storage.savePipelineState(state)
                }
            } catch {
                server.send(DaemonResponse(success: false, message: error.localizedDescription), to: clientFD)
                return
            }
        }

        server.send(DaemonResponse(success: true, message: "Runner bound: \(paneID)"), to: clientFD)
        logDaemon("Runner bound: pane=\(paneID) session=\(cmd.sessionID ?? "daemon")")
    }

    private func handleUnbindRunner(_ cmd: DaemonCommand, from clientFD: Int32) {
        guard let paneID = cmd.paneID ?? cmd.id else {
            server.send(DaemonResponse(success: false, message: "Missing pane_id"), to: clientFD)
            return
        }
        runners.removeValue(forKey: paneID)

        // Clear injection target
        if let pipeline = cmd.pipeline {
            do {
                try storage.withStateLock {
                    var state = storage.pipelineState()
                    if state.pipelines[pipeline]?.injectionTarget == paneID {
                        state.pipelines[pipeline]?.injectionTarget = nil
                        try storage.savePipelineState(state)
                    }
                }
            } catch {}
        }

        server.send(DaemonResponse(success: true, message: "Runner unbound"), to: clientFD)
    }

    private func handleIdle(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        guard let paneID = cmd.paneID ?? cmd.id else {
            server.send(DaemonResponse(success: false, message: "Missing pane_id"), to: clientFD)
            return
        }

        server.broadcast(.runnerIdle(paneID: paneID))

        // Auto-execution: if runner has an active claim, advance it
        guard let sessionID = runners[paneID] else {
            server.send(DaemonResponse(success: true, message: "No runner bound"), to: clientFD)
            return
        }

        let sessionEngine = PipelineEngine(storage: storage, sessionID: sessionID)
        let state = storage.pipelineState()

        // Find claim for this session
        var claimedPipeline: String?
        for (pipeline, entry) in state.pipelines {
            if entry.paused { continue }
            if entry.claims[sessionID] != nil {
                claimedPipeline = pipeline
                break
            }
        }

        if claimedPipeline != nil {
            // Advance the claimed job
            markSelfChange()
            let result = try sessionEngine.advance()

            switch result {
            case let .advanced(job, pipeline, _, _, prompt):
                if let prompt {
                    server.broadcast(.inject(paneID: paneID, prompt: prompt, job: job.slug))
                }
                server.send(DaemonResponse(success: true, message: "Auto-advanced \(job.slug)"), to: clientFD)
                server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .active))

            case let .manual(job, pipeline, _, to):
                server.send(DaemonResponse(success: true, message: "Waiting at \(to)"), to: clientFD)
                server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .interrupted))

            case let .completed(job, pipeline, _):
                // Auto-claim next job
                let nextResult = try sessionEngine.claim(
                    pipeline: pipeline, jobSlug: nil, stage: nil,
                    force: false, worktree: false, formatContext: false
                )
                if case let .claimed(nextJob, _, prompt) = nextResult {
                    if let prompt {
                        server.broadcast(.inject(paneID: paneID, prompt: prompt, job: nextJob.slug))
                    }
                    server.send(DaemonResponse(success: true, message: "Auto-claimed \(nextJob.slug)"), to: clientFD)
                } else {
                    server.send(DaemonResponse(success: true, message: "Completed, no more jobs"), to: clientFD)
                }
                server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .completed))

            case .noClaim, .paused:
                server.send(DaemonResponse(success: true, message: "No action"), to: clientFD)
            }
        } else {
            // No claim — auto-claim next available from any non-paused pipeline
            for pipelineName in storage.listPipelines() {
                markSelfChange()
                let result = try sessionEngine.claim(
                    pipeline: pipelineName, jobSlug: nil, stage: nil,
                    force: false, worktree: false, formatContext: false
                )
                if case let .claimed(job, pipeline, prompt) = result {
                    if let prompt {
                        server.broadcast(.inject(paneID: paneID, prompt: prompt, job: job.slug))
                    }
                    server.send(DaemonResponse(success: true, message: "Auto-claimed \(job.slug)"), to: clientFD)
                    server.broadcast(.jobStatusChanged(pipeline: pipeline, job: job.slug, status: .active))
                    break
                }
            }
        }

        lastSnapshot = takeSnapshot()
    }

    private func handleStatus(_ cmd: DaemonCommand, from clientFD: Int32) throws {
        let output = try engine.status(pipeline: cmd.pipeline, all: cmd.pipeline == nil,
                                       json: true, formatContext: false)
        let response = DaemonResponse(success: true, message: output)
        server.send(response, to: clientFD)
    }

    // MARK: - Snapshots

    func takeSnapshot() -> BoardSnapshot {
        var snapshot = BoardSnapshot()
        let state = storage.pipelineState()

        for pipelineName in storage.listPipelines() {
            guard let config = try? storage.pipelineConfig(name: pipelineName) else { continue }
            let entry = state.pipelines[pipelineName] ?? PipelineStateEntry()

            var pipelineSnap = PipelineSnapshot(
                claims: entry.claims,
                statuses: entry.jobStatuses,
                paused: entry.paused
            )

            for stage in config.stages {
                if let jobs = try? storage.jobsInStage(pipeline: pipelineName, stage: stage.directoryName) {
                    for job in jobs {
                        pipelineSnap.jobLocations[job.slug] = stage.directoryName
                    }
                }
            }

            snapshot.pipelines[pipelineName] = pipelineSnap
        }

        return snapshot
    }

    // MARK: - Helpers

    private func injectionTarget(for pipeline: String) -> String? {
        let state = storage.pipelineState()
        return state.pipelines[pipeline]?.injectionTarget
    }

    private func logDaemon(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logPath = (storage.rootPath as NSString).appendingPathComponent(".daemon.log")
        let entry = "[\(timestamp)] \(message)\n"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: Data(entry.utf8))
        }
    }
}

// MARK: - Daemon Process Management

public extension PipelineStorage {
    /// Path to daemon PID file
    var daemonPIDPath: String {
        (rootPath as NSString).appendingPathComponent(".daemon.pid")
    }

    /// Path to Unix socket
    var socketPath: String {
        (rootPath as NSString).appendingPathComponent("pipeline.sock")
    }

    /// Path to daemon log
    var daemonLogPath: String {
        (rootPath as NSString).appendingPathComponent(".daemon.log")
    }

    func writeDaemonPID(_ pid: pid_t) throws {
        try String(pid).write(toFile: daemonPIDPath, atomically: true, encoding: .utf8)
    }

    func readDaemonPID() -> pid_t? {
        guard let content = try? String(contentsOfFile: daemonPIDPath, encoding: .utf8) else { return nil }
        return pid_t(content.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func removeDaemonPID() {
        try? FileManager.default.removeItem(atPath: daemonPIDPath)
    }

    func isDaemonRunning() -> Bool {
        guard let pid = readDaemonPID() else { return false }
        return kill(pid, 0) == 0
    }

    /// Stop the daemon by sending SIGTERM
    func stopDaemon() -> Bool {
        guard let pid = readDaemonPID() else { return false }
        let result = kill(pid, SIGTERM)
        if result == 0 {
            // Wait briefly for cleanup
            usleep(200_000) // 200ms
            removeDaemonPID()
            return true
        }
        return false
    }
}
