import Testing
import Foundation
@testable import PipelineKit

// MARK: - YAML Parsing Tests

@Suite struct YAMLParsingTests {
    @Test func parsesRepoConfig() {
        let yaml = "default: feature\n"
        let config = parseRepoConfig(yaml)
        #expect(config.defaultPipeline == "feature")
    }

    @Test func parsesRepoConfigWithQuotes() {
        let yaml = "default: \"my-pipeline\"\n"
        let config = parseRepoConfig(yaml)
        #expect(config.defaultPipeline == "my-pipeline")
    }

    @Test func parsesPipelineConfig() {
        let yaml = """
        name: "Feature Pipeline"

        stages:
          - name: Backlog
            type: manual
          - name: Implement
            type: automated
          - name: Review
            type: manual
            command: "review the code"

        settings:
          pause_on_error: true
          max_claims: null
          variables: {}
        """
        let config = parsePipelineConfig(yaml)
        #expect(config.name == "Feature Pipeline")
        #expect(config.stages.count == 3)
        #expect(config.stages[0].name == "Backlog")
        #expect(config.stages[0].type == .manual)
        #expect(config.stages[1].name == "Implement")
        #expect(config.stages[1].type == .automated)
        #expect(config.stages[2].name == "Review")
        #expect(config.stages[2].command == "review the code")
        #expect(config.settings.pauseOnError == true)
        #expect(config.settings.maxClaims == nil)
    }

    @Test func parsesPipelineConfigWithMaxClaims() {
        let yaml = """
        name: Test
        stages:
          - name: Todo
            type: manual
        settings:
          pause_on_error: false
          max_claims: 3
          variables: {}
        """
        let config = parsePipelineConfig(yaml)
        #expect(config.settings.pauseOnError == false)
        #expect(config.settings.maxClaims == 3)
    }

    @Test func serializesPipelineConfig() {
        let config = PipelineConfig(
            name: "Test",
            stages: [
                Stage(name: "Backlog", type: .manual),
                Stage(name: "Run", type: .automated, command: "do stuff"),
            ]
        )
        let yaml = serializePipelineConfig(config)
        #expect(yaml.contains("name: \"Test\""))
        #expect(yaml.contains("  - name: Backlog"))
        #expect(yaml.contains("    type: manual"))
        #expect(yaml.contains("    command: \"do stuff\""))
    }

    @Test func roundTripsPipelineConfig() {
        let original = PipelineConfig(
            name: "Pipeline",
            stages: [
                Stage(name: "Backlog", type: .manual),
                Stage(name: "Build", type: .automated, command: "make build"),
                Stage(name: "Done", type: .manual),
            ],
            settings: PipelineSettings(pauseOnError: true, maxClaims: nil)
        )
        let yaml = serializePipelineConfig(original)
        let parsed = parsePipelineConfig(yaml)
        #expect(parsed.name == original.name)
        #expect(parsed.stages.count == original.stages.count)
        for (a, b) in zip(parsed.stages, original.stages) {
            #expect(a.name == b.name)
            #expect(a.type == b.type)
            #expect(a.command == b.command)
        }
    }
}

// MARK: - Frontmatter Parsing Tests

@Suite struct FrontmatterTests {
    @Test func parsesFrontmatter() {
        let content = """
        ---
        title: Refactor auth module
        priority: high
        labels: [auth, refactor]
        created: 2026-03-13T10:00:00Z
        ---

        Refactor the auth module to use async/await.
        """
        let fm = parseFrontmatter(content)
        #expect(fm.fields["title"] == "Refactor auth module")
        #expect(fm.fields["priority"] == "high")
        #expect(fm.labels == ["auth", "refactor"])
        #expect(fm.fields["created"] == "2026-03-13T10:00:00Z")
        #expect(fm.body.contains("Refactor the auth module"))
    }

    @Test func parsesBodyWithoutFrontmatter() {
        let content = "Just a plain markdown file.\n\nWith multiple paragraphs."
        let fm = parseFrontmatter(content)
        #expect(fm.fields.isEmpty)
        #expect(fm.body == content)
    }

    @Test func serializesJob() {
        let content = serializeJob(
            title: "Fix bug",
            priority: "high",
            labels: ["bug", "urgent"],
            created: "2026-03-13T10:00:00Z",
            body: "Fix the login crash."
        )
        #expect(content.contains("title: Fix bug"))
        #expect(content.contains("priority: high"))
        #expect(content.contains("labels: [bug, urgent]"))
        #expect(content.contains("Fix the login crash."))
    }
}

// MARK: - Model Tests

@Suite struct ModelTests {
    @Test func derivesSlug() {
        #expect(deriveSlug(from: "Refactor Auth Module!") == "refactor-auth-module")
        #expect(deriveSlug(from: "Fix  --  bug") == "fix-bug")
        #expect(deriveSlug(from: "simple") == "simple")
    }

    @Test func slugMaxLength() {
        let long = String(repeating: "a", count: 100)
        let slug = deriveSlug(from: long)
        #expect(slug.count <= 50)
    }

    @Test func jobNumberFromFilename() {
        #expect(jobNumber(from: "001-auth-refactor.md") == 1)
        #expect(jobNumber(from: "042-fix-bug.md") == 42)
        #expect(jobNumber(from: "no-number.md") == nil)
    }

    @Test func stageDirectoryName() {
        let stage = Stage(name: "Code Review", type: .manual)
        #expect(stage.directoryName == "code-review")
    }

    @Test func pipelineStateRoundTrips() throws {
        let state = PipelineState(pipelines: [
            "feature": PipelineStateEntry(
                claims: ["sess_1": "001-auth"],
                jobStatuses: ["001-auth": .active, "002-fix": .queued],
                paused: false,
                injectionTarget: nil
            )
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(PipelineState.self, from: data)
        #expect(decoded.pipelines["feature"]?.claims["sess_1"] == "001-auth")
        #expect(decoded.pipelines["feature"]?.jobStatuses["001-auth"] == .active)
        #expect(decoded.pipelines["feature"]?.paused == false)
    }
}

// MARK: - Storage Tests

@Suite struct StorageTests {
    let tempDir: String

    init() throws {
        tempDir = NSTemporaryDirectory() + "pipeline-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    @Test func createsAndReadsPipeline() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        let config = PipelineConfig(
            name: "Test",
            stages: [
                Stage(name: "Todo", type: .manual),
                Stage(name: "Done", type: .manual),
            ]
        )
        try storage.createPipeline(name: "test", config: config)

        let read = try storage.pipelineConfig(name: "test")
        #expect(read.name == "Test")
        #expect(read.stages.count == 2)
    }

    @Test func listsJobsInStage() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        let config = PipelineConfig(
            name: "Test",
            stages: [Stage(name: "Backlog", type: .manual), Stage(name: "Done", type: .manual)]
        )
        try storage.createPipeline(name: "test", config: config)

        // Create a job file
        let content = serializeJob(title: "First task", body: "Do the thing.")
        try storage.writeJob(pipeline: "test", stage: "backlog", filename: "001-first-task.md", content: content)

        let jobs = try storage.jobsInStage(pipeline: "test", stage: "backlog")
        #expect(jobs.count == 1)
        #expect(jobs[0].title == "First task")
        #expect(jobs[0].slug == "001-first-task")
        #expect(jobs[0].number == 1)
    }

    @Test func movesJobBetweenStages() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        let config = PipelineConfig(
            name: "Test",
            stages: [Stage(name: "Backlog", type: .manual), Stage(name: "Done", type: .manual)]
        )
        try storage.createPipeline(name: "test", config: config)

        let content = serializeJob(title: "Task", body: "Do it.")
        try storage.writeJob(pipeline: "test", stage: "backlog", filename: "001-task.md", content: content)

        try storage.moveJobFile(pipeline: "test", filename: "001-task.md", fromStage: "backlog", toStage: "done")

        let backlog = try storage.jobsInStage(pipeline: "test", stage: "backlog")
        let done = try storage.jobsInStage(pipeline: "test", stage: "done")
        #expect(backlog.isEmpty)
        #expect(done.count == 1)
    }

    @Test func findsJobBySlug() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        let config = PipelineConfig(
            name: "Test",
            stages: [Stage(name: "Backlog", type: .manual), Stage(name: "Done", type: .manual)]
        )
        try storage.createPipeline(name: "test", config: config)

        let content = serializeJob(title: "My Task", body: "Details.")
        try storage.writeJob(pipeline: "test", stage: "backlog", filename: "001-my-task.md", content: content)

        let result = try storage.findJob(pipeline: "test", slug: "001-my-task")
        #expect(result != nil)
        #expect(result?.stage == "backlog")
        #expect(result?.job.title == "My Task")
    }

    @Test func nextJobNumberIncrementsCorrectly() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        let config = PipelineConfig(
            name: "Test",
            stages: [Stage(name: "Backlog", type: .manual), Stage(name: "Done", type: .manual)]
        )
        try storage.createPipeline(name: "test", config: config)

        // No jobs yet → 0
        #expect(try storage.nextJobNumber(pipeline: "test") == 0)

        // Add a job
        let content = serializeJob(title: "First", body: "")
        try storage.writeJob(pipeline: "test", stage: "backlog", filename: "000-first.md", content: content)

        // Next should be 1
        #expect(try storage.nextJobNumber(pipeline: "test") == 1)
    }

    @Test func repoConfigRoundTrips() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        try storage.initRoot(defaultPipeline: "feature")

        let config = storage.repoConfig()
        #expect(config.defaultPipeline == "feature")
    }

    @Test func pipelineStateRoundTrips() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        try storage.initRoot(defaultPipeline: "test")

        let state = PipelineState(pipelines: [
            "test": PipelineStateEntry(
                claims: ["session-1": "001-task"],
                jobStatuses: ["001-task": .active]
            )
        ])
        try storage.savePipelineState(state)

        let loaded = storage.pipelineState()
        #expect(loaded.pipelines["test"]?.claims["session-1"] == "001-task")
        #expect(loaded.pipelines["test"]?.jobStatuses["001-task"] == .active)
    }

    @Test func appendsLogToJob() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        let config = PipelineConfig(
            name: "Test",
            stages: [Stage(name: "Backlog", type: .manual)]
        )
        try storage.createPipeline(name: "test", config: config)

        let content = serializeJob(title: "Task", body: "Do it.")
        try storage.writeJob(pipeline: "test", stage: "backlog", filename: "001-task.md", content: content)

        try storage.appendLog(pipeline: "test", stage: "backlog", filename: "001-task.md", message: "Created")
        try storage.appendLog(pipeline: "test", stage: "backlog", filename: "001-task.md", message: "Claimed")

        let path = storage.jobFilePath(pipeline: "test", stage: "backlog", filename: "001-task.md")
        let updated = try String(contentsOf: path, encoding: .utf8)
        #expect(updated.contains("## Log"))
        #expect(updated.contains("Created"))
        #expect(updated.contains("Claimed"))
    }
}

// MARK: - Engine Integration Tests

@Suite struct EngineTests {
    let tempDir: String
    let storage: PipelineStorage

    init() throws {
        tempDir = NSTemporaryDirectory() + "pipeline-engine-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        storage = PipelineStorage(rootPath: tempDir)
    }

    func makeEngine(sessionID: String = "test-session") -> PipelineEngine {
        PipelineEngine(storage: storage, sessionID: sessionID)
    }

    @Test func initCreatesPipeline() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")

        #expect(storage.pipelineExists("default"))
        let config = try storage.pipelineConfig(name: "default")
        #expect(config.stages.count == 3)
        #expect(config.stages[0].name == "Backlog")
        #expect(config.stages[1].name == "Run")
        #expect(config.stages[2].name == "Done")
    }

    @Test func initCreatesNamedPipeline() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: "feature", template: "review")

        #expect(storage.pipelineExists("feature"))
        let config = try storage.pipelineConfig(name: "feature")
        #expect(config.stages.count == 4)
    }

    @Test func addJobCreatesFile() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")

        let job = try engine.addJob(pipeline: nil, title: "Fix the bug", body: "Fix it now.", stage: nil)
        #expect(job.slug == "000-fix-the-bug")
        #expect(job.stage == "backlog")

        let jobs = try storage.jobsInStage(pipeline: "default", stage: "backlog")
        #expect(jobs.count == 1)
        #expect(jobs[0].title == "Fix the bug")
    }

    @Test func addJobAutoNumbers() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")

        let job1 = try engine.addJob(pipeline: nil, title: "First", body: nil, stage: nil)
        let job2 = try engine.addJob(pipeline: nil, title: "Second", body: nil, stage: nil)
        let job3 = try engine.addJob(pipeline: nil, title: "Third", body: nil, stage: nil)

        #expect(job1.number == 0)
        #expect(job2.number == 1)
        #expect(job3.number == 2)
    }

    @Test func claimGrabsFirstAvailable() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "First", body: "Do first.", stage: nil)
        _ = try engine.addJob(pipeline: nil, title: "Second", body: "Do second.", stage: nil)

        let result = try engine.claim(
            pipeline: nil, jobSlug: nil, stage: nil,
            force: false, worktree: false, formatContext: false
        )

        if case .claimed(let job, _, _) = result {
            #expect(job.slug == "000-first")
        } else {
            Issue.record("Expected claimed result")
        }
    }

    @Test func claimSpecificJob() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "First", body: nil, stage: nil)
        _ = try engine.addJob(pipeline: nil, title: "Second", body: nil, stage: nil)

        let result = try engine.claim(
            pipeline: nil, jobSlug: "001-second", stage: nil,
            force: false, worktree: false, formatContext: false
        )

        if case .claimed(let job, _, _) = result {
            #expect(job.slug == "001-second")
        } else {
            Issue.record("Expected claimed result")
        }
    }

    @Test func doubleClaimReturnsAlreadyClaimed() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: nil, stage: nil)

        _ = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                             force: false, worktree: false, formatContext: false)
        let result = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                                      force: false, worktree: false, formatContext: false)

        if case .alreadyClaimed(let job, _) = result {
            #expect(job == "000-task")
        } else {
            Issue.record("Expected alreadyClaimed result")
        }
    }

    @Test func advanceMovesJobForward() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "review")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: "Do the work.", stage: nil)

        // Claim the job
        _ = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                             force: false, worktree: false, formatContext: false)

        // Advance: Backlog → Implement (automated)
        let result = try engine.advance()
        if case .advanced(let job, _, let from, let to, _) = result {
            #expect(from == "Backlog")
            #expect(to == "Implement")
            #expect(job.slug == "000-task")
        } else {
            Issue.record("Expected advanced result, got: \(result)")
        }
    }

    @Test func advanceToManualReleasesClaim() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "review")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: "Do it.", stage: nil)

        _ = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                             force: false, worktree: false, formatContext: false)

        // Advance to Implement (auto) - keeps claim
        _ = try engine.advance()
        // Advance to Review (manual) - releases claim
        let result = try engine.advance()

        if case .manual(_, _, let from, let to) = result {
            #expect(from == "Implement")
            #expect(to == "Review")
        } else {
            Issue.record("Expected manual result, got: \(result)")
        }

        // Verify claim is released
        let state = storage.pipelineState()
        #expect(state.pipelines["default"]?.claims["test-session"] == nil)
    }

    @Test func advanceWithoutClaimReturnsNoClaim() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")

        let result = try engine.advance()
        if case .noClaim = result {
            // OK
        } else {
            Issue.record("Expected noClaim result")
        }
    }

    @Test func releaseDropsClaim() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: nil, stage: nil)

        _ = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                             force: false, worktree: false, formatContext: false)
        try engine.release()

        let state = storage.pipelineState()
        #expect(state.pipelines["default"]?.claims["test-session"] == nil)
        #expect(state.pipelines["default"]?.jobStatuses["000-task"] == .interrupted)
    }

    @Test func multipleSessionsClaimDifferentJobs() throws {
        let engine1 = PipelineEngine(storage: storage, sessionID: "session-1")
        let engine2 = PipelineEngine(storage: storage, sessionID: "session-2")

        try engine1.initPipeline(name: nil, template: "simple")
        _ = try engine1.addJob(pipeline: nil, title: "First", body: nil, stage: nil)
        _ = try engine1.addJob(pipeline: nil, title: "Second", body: nil, stage: nil)

        let r1 = try engine1.claim(pipeline: nil, jobSlug: nil, stage: nil,
                                   force: false, worktree: false, formatContext: false)
        let r2 = try engine2.claim(pipeline: nil, jobSlug: nil, stage: nil,
                                   force: false, worktree: false, formatContext: false)

        if case .claimed(let job1, _, _) = r1, case .claimed(let job2, _, _) = r2 {
            #expect(job1.slug != job2.slug)
        } else {
            Issue.record("Expected both claims to succeed")
        }
    }

    @Test func moveJobBetweenStages() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "review")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: nil, stage: nil)

        let moved = try engine.moveJob(slug: "000-task", toStage: "review", pipeline: nil)
        #expect(moved.stage == "review")

        let backlog = try storage.jobsInStage(pipeline: "default", stage: "backlog")
        let review = try storage.jobsInStage(pipeline: "default", stage: "review")
        #expect(backlog.isEmpty)
        #expect(review.count == 1)
    }

    @Test func removeJobDeletesFile() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: nil, stage: nil)

        try engine.removeJob(slug: "000-task", pipeline: nil)

        let jobs = try storage.jobsInStage(pipeline: "default", stage: "backlog")
        #expect(jobs.isEmpty)
    }

    @Test func playAndPause() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")

        try engine.pause(pipeline: nil)
        var state = storage.pipelineState()
        #expect(state.pipelines["default"]?.paused == true)

        try engine.play(pipeline: nil)
        state = storage.pipelineState()
        #expect(state.pipelines["default"]?.paused == false)
    }

    @Test func pausedPipelineBlocksClaim() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "Task", body: nil, stage: nil)
        try engine.pause(pipeline: nil)

        do {
            _ = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                                 force: false, worktree: false, formatContext: false)
            Issue.record("Expected PipelineError.pipelinePaused")
        } catch let error as PipelineError {
            if case .pipelinePaused = error { /* OK */ }
            else { Issue.record("Wrong error: \(error)") }
        }
    }

    @Test func fullWorkflow() throws {
        // Init → Add jobs → Claim → Advance through stages → Complete
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "review")

        _ = try engine.addJob(pipeline: nil, title: "Auth refactor", body: "Refactor auth.", stage: nil)
        _ = try engine.addJob(pipeline: nil, title: "Fix sidebar", body: "Fix it.", stage: nil)

        // Claim first job
        let claimResult = try engine.claim(
            pipeline: nil, jobSlug: nil, stage: nil,
            force: false, worktree: false, formatContext: false
        )
        guard case .claimed(let job, _, _) = claimResult else {
            Issue.record("Expected claim"); return
        }
        #expect(job.slug == "000-auth-refactor")

        // Advance: Backlog → Implement (auto)
        let adv1 = try engine.advance()
        guard case .advanced(_, _, _, let to1, _) = adv1 else {
            Issue.record("Expected advance"); return
        }
        #expect(to1 == "Implement")

        // Advance: Implement → Review (manual)
        let adv2 = try engine.advance()
        guard case .manual(_, _, _, let to2) = adv2 else {
            Issue.record("Expected manual"); return
        }
        #expect(to2 == "Review")

        // Claim again (was released at manual stage)
        let reClaim = try engine.claim(
            pipeline: nil, jobSlug: "000-auth-refactor", stage: nil,
            force: false, worktree: false, formatContext: false
        )
        guard case .claimed = reClaim else {
            Issue.record("Expected re-claim"); return
        }

        // Advance: Review → Done (manual, last stage)
        let adv3 = try engine.advance()
        guard case .manual(_, _, _, let to3) = adv3 else {
            Issue.record("Expected manual for last stage, got: \(adv3)"); return
        }
        #expect(to3 == "Done")

        // Verify job is in done stage
        let done = try storage.jobsInStage(pipeline: "default", stage: "done")
        #expect(done.count == 1)
        #expect(done[0].slug == "000-auth-refactor")
    }

    @Test func interruptedJobsGetPriority() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "review")

        _ = try engine.addJob(pipeline: nil, title: "First", body: nil, stage: nil)
        _ = try engine.addJob(pipeline: nil, title: "Second", body: nil, stage: nil)

        // Claim and release first (makes it interrupted)
        _ = try engine.claim(pipeline: nil, jobSlug: "000-first", stage: nil,
                             force: false, worktree: false, formatContext: false)
        try engine.release()

        // Next claim should get the interrupted job (000-first) not queued (001-second)
        let result = try engine.claim(pipeline: nil, jobSlug: nil, stage: nil,
                                      force: false, worktree: false, formatContext: false)
        if case .claimed(let job, _, _) = result {
            #expect(job.slug == "000-first")
        } else {
            Issue.record("Expected claim")
        }
    }

    @Test func statusOutput() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "Task One", body: nil, stage: nil)

        let output = try engine.status(pipeline: nil, all: false, json: false, formatContext: false)
        #expect(output.contains("Pipeline: default"))
        #expect(output.contains("000-task-one"))
    }

    @Test func statusContextFormat() throws {
        let engine = makeEngine()
        try engine.initPipeline(name: nil, template: "simple")
        _ = try engine.addJob(pipeline: nil, title: "Task One", body: nil, stage: nil)

        let output = try engine.status(pipeline: nil, all: false, json: false, formatContext: true)
        #expect(output.contains("## Pipelines in this repo"))
        #expect(output.contains("000-task-one"))
        #expect(output.contains("pipeline claim"))
    }
}

// MARK: - Template Tests

@Suite struct TemplateTests {
    @Test func simpleTemplate() {
        let config = PipelineTemplate.simple.config
        #expect(config.stages.count == 3)
        #expect(config.stages[0].name == "Backlog")
        #expect(config.stages[0].type == .manual)
        #expect(config.stages[1].name == "Run")
        #expect(config.stages[1].type == .automated)
    }

    @Test func reviewTemplate() {
        let config = PipelineTemplate.review.config
        #expect(config.stages.count == 4)
        #expect(config.stages[2].name == "Review")
        #expect(config.stages[2].type == .manual)
    }

    @Test func fullCiTemplate() {
        let config = PipelineTemplate.fullCi.config
        #expect(config.stages.count == 6)
        #expect(config.stages[3].name == "Test")
        #expect(config.stages[3].command != nil)
        #expect(config.stages[4].name == "Commit")
        #expect(config.stages[4].command == "/commit")
    }
}

// MARK: - Template Store Tests

@Suite struct TemplateStoreTests {
    let tempDir: String

    init() throws {
        tempDir = NSTemporaryDirectory() + "template-store-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    @Test func seedsDefaultTemplates() {
        let store = TemplateStore(rootPath: tempDir)
        store.seedDefaults()

        let names = store.listTemplates()
        #expect(names.contains("simple"))
        #expect(names.contains("review"))
        #expect(names.contains("full-ci"))
    }

    @Test func seedDefaultsOnlyWhenEmpty() throws {
        let store = TemplateStore(rootPath: tempDir)
        // Save a custom template first
        let custom = PipelineConfig(name: "Custom", stages: [Stage(name: "Start", type: .manual)])
        try store.saveTemplate(name: "custom", config: custom)

        // Seed should not overwrite or add defaults since directory is not empty
        store.seedDefaults()
        let names = store.listTemplates()
        #expect(names == ["custom"])
    }

    @Test func loadsSavedTemplate() throws {
        let store = TemplateStore(rootPath: tempDir)
        let config = PipelineConfig(
            name: "My Template",
            stages: [
                Stage(name: "Todo", type: .manual),
                Stage(name: "Build", type: .automated, command: "make build"),
                Stage(name: "Done", type: .manual),
            ]
        )
        try store.saveTemplate(name: "my-template", config: config)

        let loaded = try store.loadTemplate(name: "my-template")
        #expect(loaded.name == "My Template")
        #expect(loaded.stages.count == 3)
        #expect(loaded.stages[1].command == "make build")
    }

    @Test func loadNonexistentThrows() {
        let store = TemplateStore(rootPath: tempDir)
        #expect(throws: PipelineError.self) {
            _ = try store.loadTemplate(name: "nonexistent")
        }
    }

    @Test func deletesTemplate() throws {
        let store = TemplateStore(rootPath: tempDir)
        let config = PipelineConfig(name: "Temp", stages: [Stage(name: "A", type: .manual)])
        try store.saveTemplate(name: "temp", config: config)
        #expect(store.listTemplates().contains("temp"))

        try store.deleteTemplate(name: "temp")
        #expect(!store.listTemplates().contains("temp"))
    }

    @Test func deleteNonexistentThrows() {
        let store = TemplateStore(rootPath: tempDir)
        #expect(throws: PipelineError.self) {
            try store.deleteTemplate(name: "nonexistent")
        }
    }

    @Test func templatePathIsCorrect() {
        let store = TemplateStore(rootPath: "/tmp/templates")
        #expect(store.templatePath(name: "review") == "/tmp/templates/review.yaml")
    }

    @Test func listTemplatesIsSorted() throws {
        let store = TemplateStore(rootPath: tempDir)
        let config = PipelineConfig(name: "T", stages: [Stage(name: "A", type: .manual)])
        try store.saveTemplate(name: "zebra", config: config)
        try store.saveTemplate(name: "alpha", config: config)
        try store.saveTemplate(name: "middle", config: config)

        #expect(store.listTemplates() == ["alpha", "middle", "zebra"])
    }
}

// MARK: - Event Tests

@Suite struct EventTests {
    @Test func eventSerializesToJSON() throws {
        let event = PipelineEvent.jobMoved(pipeline: "feature", job: "001-auth", from: "backlog", to: "implement")
        let data = event.jsonLine()
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("\"event\":\"job_moved\""))
        #expect(str.contains("\"job\":\"001-auth\""))
        #expect(str.hasSuffix("\n"))
    }

    @Test func eventRoundTrips() throws {
        let original = PipelineEvent.jobStatusChanged(pipeline: "bugs", job: "002-fix", status: .active)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PipelineEvent.self, from: data)
        #expect(decoded.event == "job_status_changed")
        #expect(decoded.job == "002-fix")
        #expect(decoded.status == "active")
        #expect(decoded.pipeline == "bugs")
    }

    @Test func commandDeserializes() throws {
        let json = """
        {"command": "advance", "job": "003", "session_id": "sess_1"}
        """
        let cmd = try JSONDecoder().decode(DaemonCommand.self, from: Data(json.utf8))
        #expect(cmd.command == "advance")
        #expect(cmd.job == "003")
        #expect(cmd.sessionID == "sess_1")
    }

    @Test func responseSerializes() throws {
        let response = DaemonResponse(success: true, message: "OK")
        let data = response.jsonLine()
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("\"success\":true"))
        #expect(str.contains("\"message\":\"OK\""))
    }
}

// MARK: - Snapshot Diff Tests

@Suite struct SnapshotDiffTests {
    @Test func detectsJobMove() {
        let old = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(
                jobLocations: ["001-auth": "backlog"],
                statuses: ["001-auth": .queued]
            )
        ])
        let new = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(
                jobLocations: ["001-auth": "implement"],
                statuses: ["001-auth": .active]
            )
        ])
        let events = diffSnapshots(old: old, new: new)
        let moveEvent = events.first(where: { $0.event == "job_moved" })
        #expect(moveEvent != nil)
        #expect(moveEvent?.from == "backlog")
        #expect(moveEvent?.to == "implement")
    }

    @Test func detectsJobAdded() {
        let old = BoardSnapshot(pipelines: ["feature": PipelineSnapshot()])
        let new = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(jobLocations: ["001-task": "backlog"])
        ])
        let events = diffSnapshots(old: old, new: new)
        #expect(events.contains(where: { $0.event == "job_added" && $0.job == "001-task" }))
    }

    @Test func detectsJobRemoved() {
        let old = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(jobLocations: ["001-task": "backlog"])
        ])
        let new = BoardSnapshot(pipelines: ["feature": PipelineSnapshot()])
        let events = diffSnapshots(old: old, new: new)
        #expect(events.contains(where: { $0.event == "job_removed" && $0.job == "001-task" }))
    }

    @Test func detectsStatusChange() {
        let old = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(statuses: ["001-task": .queued])
        ])
        let new = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(statuses: ["001-task": .active])
        ])
        let events = diffSnapshots(old: old, new: new)
        #expect(events.contains(where: { $0.event == "job_status_changed" && $0.status == "active" }))
    }

    @Test func detectsPauseToggle() {
        let old = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(paused: false)
        ])
        let new = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(paused: true)
        ])
        let events = diffSnapshots(old: old, new: new)
        #expect(events.contains(where: { $0.event == "pipeline_paused" }))
    }

    @Test func noEventsWhenUnchanged() {
        let snapshot = BoardSnapshot(pipelines: [
            "feature": PipelineSnapshot(
                jobLocations: ["001-task": "backlog"],
                statuses: ["001-task": .queued],
                paused: false
            )
        ])
        let events = diffSnapshots(old: snapshot, new: snapshot)
        #expect(events.isEmpty)
    }
}

// MARK: - Daemon Storage Extension Tests

@Suite struct DaemonStorageTests {
    let tempDir: String

    init() throws {
        tempDir = NSTemporaryDirectory() + "pipeline-daemon-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    @Test func pidFileLifecycle() throws {
        let storage = PipelineStorage(rootPath: tempDir)
        #expect(storage.readDaemonPID() == nil)
        #expect(!storage.isDaemonRunning())

        try storage.writeDaemonPID(getpid())
        #expect(storage.readDaemonPID() == getpid())
        #expect(storage.isDaemonRunning()) // current process is alive

        storage.removeDaemonPID()
        #expect(storage.readDaemonPID() == nil)
    }

    @Test func socketPath() {
        let storage = PipelineStorage(rootPath: "/tmp/test-pipeline")
        #expect(storage.socketPath == "/tmp/test-pipeline/pipeline.sock")
    }
}
