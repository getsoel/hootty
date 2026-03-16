import Foundation
import PipelineKit

// MARK: - Pipeline Subcommand Dispatcher

func handlePipelineCommand(_ args: [String]) throws {
    guard let command = args.first else {
        printPipelineUsage()
        exit(0)
    }
    let remaining = Array(args.dropFirst())

    switch command {
    case "init":
        try handleInit(remaining)
    case "delete":
        try handleDelete(remaining)
    case "status":
        try handleStatus(remaining)
    case "add":
        try handleAdd(remaining)
    case "edit":
        try handleEdit(remaining)
    case "move":
        try handleMove(remaining)
    case "remove":
        try handleRemove(remaining)
    case "archive":
        try handleArchive(remaining)
    case "log":
        try handleLog(remaining)
    case "claim":
        try handleClaim(remaining)
    case "advance":
        try handleAdvance(remaining)
    case "release":
        try handleRelease(remaining)
    case "current-job":
        try handleCurrentJob(remaining)
    case "whoami":
        try handleWhoami(remaining)
    case "reap":
        try handleReap(remaining)
    case "play":
        try handlePlay(remaining)
    case "pause":
        try handlePause(remaining)
    case "stage":
        try handleStage(remaining)
    case "daemon":
        try handleDaemon(remaining)
    case "inject-target":
        try handleInjectTarget(remaining)
    case "listen":
        try handleListen(remaining)
    case "help", "--help", "-h":
        printPipelineUsage()
    case "version", "--version":
        print("hootty pipeline 0.1.0")
    default:
        printError("Unknown pipeline command: \(command)")
        printPipelineUsage()
        exit(1)
    }
}

// MARK: - Engine Setup

func makeEngine() throws -> PipelineEngine {
    let rootPath = try PipelineStorage.findRoot()
    let storage = PipelineStorage(rootPath: rootPath)
    let sessionID = resolveSessionID()
    return PipelineEngine(storage: storage, sessionID: sessionID)
}

func makeEngineForInit() throws -> PipelineEngine {
    // For init, we create the root if it doesn't exist
    let repoRoot = try PipelineStorage.canonicalRepoRoot()
    let hoottyDir = (repoRoot as NSString).appendingPathComponent(".hootty")
    let rootPath = (hoottyDir as NSString).appendingPathComponent("pipeline")
    let storage = PipelineStorage(rootPath: rootPath)
    let sessionID = resolveSessionID()
    return PipelineEngine(storage: storage, sessionID: sessionID)
}

// MARK: - Command Handlers

func handleInit(_ args: [String]) throws {
    let flags = Flags(args)
    let name = flags.positional.first
    let template = flags.get("template")
    let engine = try makeEngineForInit()
    try engine.initPipeline(name: name, template: template)
    let pipelineName = name ?? "default"
    print("✓ Created pipeline: \(pipelineName)")
    if let tmpl = template {
        print("  Template: \(tmpl)")
    }

    // --hooks: create .claude/hooks.json for Claude Code integration
    if flags.has("hooks") {
        try createClaudeHooks()
    }
}

func handleDelete(_ args: [String]) throws {
    let flags = Flags(args)
    guard let name = flags.positional.first else {
        printError("Usage: hootty pipeline delete <name> [--yes]")
        exit(1)
    }
    if !flags.has("yes") {
        print("Delete pipeline \"\(name)\" and all its jobs? This cannot be undone.")
        print("Run with --yes to confirm.")
        exit(1)
    }
    let engine = try makeEngine()
    try engine.deletePipeline(name: name)
    print("✓ Deleted pipeline: \(name)")
}

func handleStatus(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()
    let pipeline = flags.positional.first
    let output = try engine.status(
        pipeline: pipeline,
        all: flags.has("all"),
        json: flags.has("json"),
        formatContext: flags.get("format") == "context"
    )
    print(output)
}

func handleAdd(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()

    // Determine pipeline and title from positional args
    let pipeline: String?
    let title: String

    if flags.positional.count >= 2 {
        // Check if first arg is a known pipeline
        let possiblePipeline = flags.positional[0]
        if engine.storage.pipelineExists(possiblePipeline) {
            pipeline = possiblePipeline
            title = flags.positional[1...].joined(separator: " ")
        } else {
            pipeline = nil
            title = flags.positional.joined(separator: " ")
        }
    } else if flags.positional.count == 1 {
        pipeline = nil
        title = flags.positional[0]
    } else {
        printError("Usage: hootty pipeline add [<pipeline>] <title> [--body \"text\"] [--stage <stage>] [--edit]")
        exit(1)
    }

    let job = try engine.addJob(
        pipeline: pipeline,
        title: title,
        body: flags.get("body"),
        stage: flags.get("stage")
    )

    print("✓ Added job: \(job.slug)")
    print("  Stage: \(job.stage)")

    // Open in editor if --edit
    if flags.has("edit") {
        let pipelineName = try engine.resolveDefaultPipeline(pipeline)
        let path = engine.storage.jobFilePath(
            pipeline: pipelineName,
            stage: job.stage,
            filename: job.filename
        )
        try openEditor(path: path.path)
    }
}

func handleEdit(_ args: [String]) throws {
    let flags = Flags(args)
    guard let target = flags.positional.first else {
        printError("Usage: hootty pipeline edit <job-slug|memory>")
        exit(1)
    }

    let engine = try makeEngine()

    if target == "memory" {
        let memoryPath = (engine.storage.rootPath as NSString).appendingPathComponent("memory.md")
        if !FileManager.default.fileExists(atPath: memoryPath) {
            try "".write(toFile: memoryPath, atomically: true, encoding: .utf8)
        }
        try openEditor(path: memoryPath)
        return
    }

    // Find job across all pipelines
    for pipelineName in engine.storage.listPipelines() {
        if let (stage, job) = try engine.storage.findJob(pipeline: pipelineName, slug: target) {
            let path = engine.storage.jobFilePath(pipeline: pipelineName, stage: stage, filename: job.filename)
            try openEditor(path: path.path)
            return
        }
    }

    printError("Job \"\(target)\" not found.")
    exit(1)
}

func handleMove(_ args: [String]) throws {
    let flags = Flags(args)
    guard flags.positional.count >= 2 else {
        printError("Usage: hootty pipeline move <job-slug> <stage>")
        exit(1)
    }

    let slug = flags.positional[0]
    let toStage = flags.positional[1]
    let engine = try makeEngine()
    let job = try engine.moveJob(slug: slug, toStage: toStage, pipeline: flags.get("pipeline"))

    print("✓ Moved \(job.slug) → \(job.stage)")
}

func handleRemove(_ args: [String]) throws {
    let flags = Flags(args)
    guard let slug = flags.positional.first else {
        printError("Usage: hootty pipeline remove <job-slug>")
        exit(1)
    }

    let engine = try makeEngine()
    try engine.removeJob(slug: slug, pipeline: flags.get("pipeline"))
    print("✓ Removed job: \(slug)")
}

func handleArchive(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()
    let count = try engine.archiveJobs(pipeline: flags.positional.first)
    print("✓ Archived \(count) job(s)")
}

func handleLog(_ args: [String]) throws {
    let message = args.joined(separator: " ")
    guard !message.isEmpty else {
        printError("Usage: hootty pipeline log <message>")
        exit(1)
    }

    let engine = try makeEngine()
    try engine.logMessage(message)
    print("✓ Log entry added")
}

func handleClaim(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()

    let pipeline = flags.positional.first
    let formatContext = flags.get("format") == "context"

    let result = try engine.claim(
        pipeline: pipeline,
        jobSlug: flags.get("job"),
        stage: flags.get("stage"),
        force: flags.has("force"),
        worktree: flags.has("worktree"),
        formatContext: formatContext
    )

    switch result {
    case .claimed(let job, _, let prompt):
        if formatContext {
            // In context mode, just output the context
            if let prompt = prompt {
                print(prompt)
            }
        } else {
            print("✓ Claimed job: \(job.slug) (stage: \(job.stage))")
            if flags.has("worktree") {
                let repoRoot = try PipelineStorage.canonicalRepoRoot()
                print("▶ Working directory: \(repoRoot)/.claude/worktrees/pipeline/\(job.slug)")
            }
            if let prompt = prompt {
                print("▶ Prompt:")
                print(prompt)
            }
        }

    case .noJobsAvailable(let pipelineName):
        if formatContext {
            // Silent in context mode
        } else {
            printError("No jobs available to claim in pipeline \"\(pipelineName)\".")
        }
        exit(1)

    case .alreadyClaimed(let currentJob, _):
        printError("You already have a claim on \"\(currentJob)\". Run `hootty pipeline release` first.")
        exit(1)
    }
}

func handleAdvance(_ args: [String]) throws {
    let engine = try makeEngine()
    let result = try engine.advance()

    switch result {
    case .advanced(let job, _, let fromStage, let toStage, let nextPrompt):
        print("✓ Job \"\(job.slug)\" advanced: \(fromStage) → \(toStage) (automated)")
        if let prompt = nextPrompt {
            print("▶ Next prompt:")
            print(prompt)
        }

    case .manual(let job, _, let fromStage, let toStage):
        print("✓ Job \"\(job.slug)\" advanced: \(fromStage) → \(toStage) (manual)")
        print("⏸ Waiting for human review. Claim released.")

    case .completed(let job, _, let fromStage):
        print("✓ Job \"\(job.slug)\" completed (from \(fromStage)).")
        print("✓ Claim released.")

    case .noClaim:
        printError("No active claim. Run `hootty pipeline claim` first.")
        exit(1)

    case .paused:
        printError("Pipeline is paused. Run `hootty pipeline play` to resume.")
        exit(1)
    }
}

func handleRelease(_ args: [String]) throws {
    let engine = try makeEngine()
    try engine.release()
    print("✓ Claim released.")
}

func handleCurrentJob(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()
    let formatContext = flags.get("format") == "context" || flags.has("format")
    let output = try engine.currentJob(formatContext: formatContext && flags.get("format") == "context")
    print(output)
}

func handleWhoami(_ args: [String]) throws {
    let engine = try makeEngine()
    print(engine.whoami())
}

func handleReap(_ args: [String]) throws {
    let engine = try makeEngine()
    let reaped = engine.reap()
    if reaped.isEmpty {
        print("No stale claims found.")
    } else {
        print("Reaped \(reaped.count) stale claim(s):")
        for entry in reaped {
            print("  \(entry)")
        }
    }
}

func handlePlay(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()
    try engine.play(pipeline: flags.positional.first)
    print("▶ Pipeline resumed.")
}

func handlePause(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()
    try engine.pause(pipeline: flags.positional.first)
    print("⏸ Pipeline paused.")
}

func handleStage(_ args: [String]) throws {
    guard let subcommand = args.first else {
        printError("Usage: hootty pipeline stage <add|remove|move> ...")
        exit(1)
    }

    let remaining = Array(args.dropFirst())
    let flags = Flags(remaining)
    let engine = try makeEngine()

    switch subcommand {
    case "add":
        guard let name = flags.positional.first else {
            printError("Usage: hootty pipeline stage add <name> [--type auto|manual] [--after <stage>] [--pipeline <name>]")
            exit(1)
        }
        let typeStr = flags.get("type") ?? "manual"
        let type: StageType = typeStr == "auto" || typeStr == "automated" ? .automated : .manual
        try engine.addStage(pipeline: flags.get("pipeline"), name: name, type: type, after: flags.get("after"))
        print("✓ Added stage: \(name) (\(type.rawValue))")

    case "remove":
        guard let name = flags.positional.first else {
            printError("Usage: hootty pipeline stage remove <name> [--pipeline <name>]")
            exit(1)
        }
        try engine.removeStage(pipeline: flags.get("pipeline"), name: name)
        print("✓ Removed stage: \(name)")

    case "move":
        guard let name = flags.positional.first, let after = flags.get("after") else {
            printError("Usage: hootty pipeline stage move <name> --after <stage> [--pipeline <name>]")
            exit(1)
        }
        try engine.moveStage(pipeline: flags.get("pipeline"), name: name, after: after)
        print("✓ Moved stage: \(name)")

    default:
        printError("Unknown stage subcommand: \(subcommand)")
        exit(1)
    }
}

func handleDaemon(_ args: [String]) throws {
    guard let subcommand = args.first else {
        printError("Usage: hootty pipeline daemon <start|stop|status|run>")
        exit(1)
    }

    switch subcommand {
    case "start":
        let rootPath = try PipelineStorage.findRoot()
        let storage = PipelineStorage(rootPath: rootPath)

        if storage.isDaemonRunning() {
            print("Daemon is already running (PID: \(storage.readDaemonPID() ?? 0)).")
            exit(0)
        }

        // Spawn daemon in background
        let execPath = ProcessInfo.processInfo.arguments[0]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = ["pipeline", "daemon", "run"]
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Redirect stdout/stderr to daemon log
        let logPath = storage.daemonLogPath
        FileManager.default.createFile(atPath: logPath, contents: nil)
        if let logHandle = FileHandle(forWritingAtPath: logPath) {
            process.standardOutput = logHandle
            process.standardError = logHandle
        } else {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }
        process.standardInput = FileHandle.nullDevice

        // Copy environment
        var env = ProcessInfo.processInfo.environment
        env["PIPELINE_DAEMON"] = "1"
        process.environment = env

        try process.run()

        // Wait briefly for daemon to start and write PID
        usleep(300_000) // 300ms
        if storage.isDaemonRunning() {
            print("✓ Daemon started (PID: \(storage.readDaemonPID() ?? 0))")
            print("  Socket: \(storage.socketPath)")
            print("  Log: \(logPath)")
        } else {
            printError("Daemon failed to start. Check \(logPath)")
            exit(1)
        }

    case "stop":
        let rootPath = try PipelineStorage.findRoot()
        let storage = PipelineStorage(rootPath: rootPath)

        if storage.stopDaemon() {
            print("✓ Daemon stopped.")
        } else {
            print("No daemon running.")
        }

    case "status":
        let rootPath = try PipelineStorage.findRoot()
        let storage = PipelineStorage(rootPath: rootPath)

        if let pid = storage.readDaemonPID(), storage.isDaemonRunning() {
            print("Daemon running (PID: \(pid))")
            print("  Socket: \(storage.socketPath)")
        } else {
            print("Daemon not running.")
        }

    case "run":
        // Internal command: actually run the daemon process
        let rootPath = try PipelineStorage.findRoot()
        let storage = PipelineStorage(rootPath: rootPath)
        let daemon = PipelineDaemon(storage: storage)
        try daemon.run()
        // run() blocks forever (dispatchMain)

    default:
        printError("Unknown daemon subcommand: \(subcommand)")
        exit(1)
    }
}

func handleInjectTarget(_ args: [String]) throws {
    let flags = Flags(args)
    let engine = try makeEngine()

    guard let paneID = flags.get("pane") else {
        // Show current injection target
        let state = engine.storage.pipelineState()
        let pipelineName = try engine.resolveDefaultPipeline(flags.positional.first)
        if let target = state.pipelines[pipelineName]?.injectionTarget {
            print("Injection target: \(target) (pipeline: \(pipelineName))")
        } else {
            print("No injection target set for pipeline \"\(pipelineName)\".")
        }
        return
    }

    // Set injection target
    let pipelineName = try engine.resolveDefaultPipeline(flags.positional.first)
    try engine.storage.withStateLock {
        var state = engine.storage.pipelineState()
        if state.pipelines[pipelineName] == nil {
            state.pipelines[pipelineName] = PipelineStateEntry()
        }
        state.pipelines[pipelineName]?.injectionTarget = paneID
        try engine.storage.savePipelineState(state)
    }

    print("✓ Injection target set: \(paneID) (pipeline: \(pipelineName))")

    // If daemon is running, send bind_runner command
    if engine.storage.isDaemonRunning() {
        print("  (Daemon running — runner will be bound on next connection)")
    }
}

func handleListen(_ args: [String]) throws {
    let rootPath = try PipelineStorage.findRoot()
    let storage = PipelineStorage(rootPath: rootPath)

    guard storage.isDaemonRunning() else {
        printError("Daemon not running. Start it with `hootty pipeline daemon start`.")
        exit(1)
    }

    print("Connecting to daemon at \(storage.socketPath)...")
    print("Listening for events (Ctrl+C to stop):\n")

    // Connect to the Unix socket
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        printError("Failed to create socket")
        exit(1)
    }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(storage.socketPath.utf8)
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        let raw = UnsafeMutableRawPointer(ptr)
        for (i, byte) in pathBytes.enumerated() {
            raw.storeBytes(of: Int8(bitPattern: byte), toByteOffset: i, as: Int8.self)
        }
        raw.storeBytes(of: Int8(0), toByteOffset: pathBytes.count, as: Int8.self)
    }

    let connectResult = withUnsafePointer(to: &addr) { addrPtr in
        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
            connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connectResult == 0 else {
        printError("Failed to connect to daemon socket")
        close(fd)
        exit(1)
    }

    // Read and print events
    var buffer = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
        let bytesRead = read(fd, &buf, buf.count)
        if bytesRead <= 0 { break }
        buffer.append(contentsOf: buf[0..<bytesRead])

        while let newlineIdx = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = Data(buffer[buffer.startIndex..<newlineIdx])
            buffer = Data(buffer[buffer.index(after: newlineIdx)...])
            if let str = String(data: line, encoding: .utf8) {
                print(str)
            }
        }
    }

    close(fd)
    print("\nDisconnected.")
}

// MARK: - Helpers

func openEditor(path: String) throws {
    let editor = ProcessInfo.processInfo.environment["EDITOR"]
        ?? ProcessInfo.processInfo.environment["VISUAL"]
        ?? "vi"

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [editor, path]
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
}

func createClaudeHooks() throws {
    let repoRoot = try PipelineStorage.canonicalRepoRoot()
    let claudeDir = (repoRoot as NSString).appendingPathComponent(".claude")
    let hooksPath = (claudeDir as NSString).appendingPathComponent("hooks.json")

    try FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)

    if FileManager.default.fileExists(atPath: hooksPath) {
        print("  .claude/hooks.json already exists (not overwritten)")
        return
    }

    let hooksJSON = """
    {
      "hooks": {
        "session_start": [
          {
            "command": "hootty pipeline status --format context 2>/dev/null || true",
            "description": "Inject pipeline board awareness"
          }
        ]
      }
    }
    """
    try hooksJSON.write(toFile: hooksPath, atomically: true, encoding: .utf8)
    print("  ✓ Created .claude/hooks.json (pipeline awareness on session start)")
}

func printPipelineUsage() {
    print("""
    hootty pipeline — CLI-driven kanban for AI agent task management

    Usage: hootty pipeline <command> [options]

    Pipeline management:
      init [<name>] [--template simple|review|full-ci] [--hooks]  Create a pipeline
      delete <name> [--yes]       Delete a pipeline
      status [<name>] [--all] [--json] [--format context]  Show board state
      play [<name>]               Resume pipeline
      pause [<name>]              Pause pipeline

    Job management:
      add [<pipeline>] <title> [--body "text"] [--stage <stage>] [--edit]
      edit <job-slug|memory>      Open in $EDITOR
      move <job-slug> <stage>     Move job to stage
      remove <job-slug>           Delete a job
      archive [<pipeline>]        Archive completed jobs
      log <message>               Append note to claimed job

    Claiming:
      claim [<pipeline>] [--job <slug>] [--stage <stage>] [--force] [--worktree] [--format context]
      advance                     Advance claimed job to next stage
      release                     Release claim without advancing
      current-job [--format context]  Show current claim

    Session:
      whoami                      Show session ID and claims
      reap                        Clean up stale claims

    Stage management:
      stage add <name> [--type auto|manual] [--after <stage>]
      stage remove <name>
      stage move <name> --after <stage>

    Daemon:
      daemon start                Start background daemon
      daemon stop                 Stop daemon
      daemon status               Check daemon state
      inject-target [--pane <id>] Set/show injection target
      listen                      Subscribe to daemon events (debug)
    """)
}
