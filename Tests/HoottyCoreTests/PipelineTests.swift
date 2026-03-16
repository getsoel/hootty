import Foundation
import Testing
@testable import HoottyCore

struct PipelineStateTests {
    @Test func decodesStateFile() throws {
        let json = """
        {
          "pipelines": {
            "default": {
              "claims": { "abc-123": "000-update-docs" },
              "job_statuses": { "000-update-docs": "active" },
              "paused": false
            }
          }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let state = try JSONDecoder().decode(PipelineStateFile.self, from: data)

        #expect(state.pipelines.count == 1)
        let runtime = try #require(state.pipelines["default"])
        #expect(runtime.claims["abc-123"] == "000-update-docs")
        #expect(runtime.job_statuses["000-update-docs"] == "active")
        #expect(runtime.paused == false)
    }

    @Test func decodesEmptyPipelines() throws {
        let json = """
        { "pipelines": {} }
        """
        let data = try #require(json.data(using: .utf8))
        let state = try JSONDecoder().decode(PipelineStateFile.self, from: data)
        #expect(state.pipelines.isEmpty)
    }
}

struct PipelineReaderTests {
    @Test func parsesPipelineYAML() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        try FileManager.default.createDirectory(at: pipelineDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = """
        name: "Test Pipeline"

        stages:
          - name: Backlog
            type: manual
          - name: Implement
            type: automated
          - name: Review
            type: manual
          - name: Done
            type: manual

        settings:
          pause_on_error: true
        """
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "default")
        #expect(config != nil)
        #expect(config?.name == "Test Pipeline")
        #expect(config?.stages.count == 4)
        #expect(config?.stages[0].name == "Backlog")
        #expect(config?.stages[0].type == .manual)
        #expect(config?.stages[0].command == nil)
        #expect(config?.stages[1].name == "Implement")
        #expect(config?.stages[1].type == .automated)
    }

    @Test func parsesPipelineYAMLWithCommands() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        try FileManager.default.createDirectory(at: pipelineDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = """
        name: "SDD Pipeline"

        stages:
          - name: Backlog
            type: manual
          - name: Research
            type: automated
            command: "Research the codebase relevant to this job."
          - name: Implement
            type: automated
          - name: Commit
            type: automated
            command: "/commit"
          - name: Done
            type: manual
        """
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "default")
        #expect(config != nil)
        #expect(config?.name == "SDD Pipeline")
        #expect(config?.stages.count == 5)
        #expect(config?.stages[0].command == nil)
        #expect(config?.stages[1].command == "Research the codebase relevant to this job.")
        #expect(config?.stages[2].command == nil)
        #expect(config?.stages[3].command == "/commit")
        #expect(config?.stages[4].command == nil)
    }

    @Test func commandFieldBackwardCompatible() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        try FileManager.default.createDirectory(at: pipelineDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = """
        name: "Legacy Pipeline"

        stages:
          - name: Backlog
            type: manual
          - name: Done
            type: manual
        """
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "default")
        #expect(config != nil)
        #expect(config?.stages.count == 2)
        #expect(config?.stages[0].command == nil)
        #expect(config?.stages[1].command == nil)
    }

    @Test func hasPipelineDetectsDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(!PipelineReader.hasPipeline(repoRoot: tempDir.path))

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent(".hootty/pipeline"), withIntermediateDirectories: true)
        #expect(PipelineReader.hasPipeline(repoRoot: tempDir.path))
    }

    @Test func findsJobInStageDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let backlogDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        let implementDir = tempDir.appendingPathComponent(".hootty/pipeline/default/implement")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: implementDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: my task\n---\n".write(
            to: implementDir.appendingPathComponent("001-my-task.md"),
            atomically: true, encoding: .utf8
        )

        let stages = [
            PipelineStageDef(name: "Backlog", type: .manual),
            PipelineStageDef(name: "Implement", type: .automated)
        ]

        let index = PipelineReader.findJobStage(
            repoRoot: tempDir.path, pipelineName: "default",
            stages: stages, jobSlug: "001-my-task"
        )
        #expect(index == 1)
    }

    @Test func readsJobTitleFromFrontmatter() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: Update Documentation\ncreated: 2026-01-01\n---\n\nSome body".write(
            to: stageDir.appendingPathComponent("000-update-docs.md"),
            atomically: true, encoding: .utf8
        )

        let stages = [PipelineStageDef(name: "Backlog", type: .manual)]
        let title = PipelineReader.readJobTitle(
            repoRoot: tempDir.path, pipelineName: "default",
            stages: stages, jobSlug: "000-update-docs"
        )
        #expect(title == "Update Documentation")
    }

    @Test func resolveClaimMatchesSessionID() {
        let state = PipelineStateFile(pipelines: [
            "default": PipelineRuntimeState(
                claims: ["pane-abc": "001-task"],
                job_statuses: ["001-task": "active"],
                paused: false
            )
        ])

        let result = PipelineReader.resolveClaimForSession(stateFile: state, sessionIDs: ["pane-abc"])
        #expect(result?.pipelineName == "default")
        #expect(result?.jobSlug == "001-task")
    }

    @Test func readsAllJobsAcrossStages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        let implementDir = pipelineDir.appendingPathComponent("implement")
        let doneDir = pipelineDir.appendingPathComponent("done")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: implementDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: doneDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: First Task\n---\n".write(to: backlogDir.appendingPathComponent("001-first.md"), atomically: true, encoding: .utf8)
        try "---\ntitle: Second Task\n---\n".write(to: implementDir.appendingPathComponent("002-second.md"), atomically: true, encoding: .utf8)
        try "---\ntitle: Third Task\n---\n".write(to: doneDir.appendingPathComponent("003-third.md"), atomically: true, encoding: .utf8)

        let stages = [
            PipelineStageDef(name: "Backlog", type: .manual),
            PipelineStageDef(name: "Implement", type: .automated),
            PipelineStageDef(name: "Done", type: .manual)
        ]
        let jobs = PipelineReader.readAllJobs(repoRoot: tempDir.path, pipelineName: "default", stages: stages)

        #expect(jobs.count == 3)
        #expect(jobs[0].slug == "001-first")
        #expect(jobs[0].title == "First Task")
        #expect(jobs[0].stageIndex == 0)
        #expect(jobs[1].stageIndex == 1)
        #expect(jobs[2].stageIndex == 2)
    }

    @Test func resolveClaimReturnsNilForNoMatch() {
        let state = PipelineStateFile(pipelines: [
            "default": PipelineRuntimeState(
                claims: ["other-session": "001-task"],
                job_statuses: [:],
                paused: false
            )
        ])

        let result = PipelineReader.resolveClaimForSession(stateFile: state, sessionIDs: ["my-session"])
        #expect(result == nil)
    }

    @Test func parsesFrontmatterPriorityAndLabels() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try """
        ---
        title: Auth Refactor
        priority: high
        labels: auth, refactor
        ---

        Refactor the auth module.
        """.write(to: stageDir.appendingPathComponent("001-auth-refactor.md"), atomically: true, encoding: .utf8)

        let stages = [PipelineStageDef(name: "Backlog", type: .manual)]
        let jobs = PipelineReader.readAllJobs(repoRoot: tempDir.path, pipelineName: "default", stages: stages)

        #expect(jobs.count == 1)
        #expect(jobs[0].title == "Auth Refactor")
        #expect(jobs[0].priority == "high")
        #expect(jobs[0].labels == ["auth", "refactor"])
    }

    @Test func readsJobBody() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try """
        ---
        title: My Task
        ---

        This is the task body.
        It has multiple lines.
        """.write(to: stageDir.appendingPathComponent("001-my-task.md"), atomically: true, encoding: .utf8)

        let stages = [PipelineStageDef(name: "Backlog", type: .manual)]
        let body = PipelineReader.readJobBody(repoRoot: tempDir.path, pipelineName: "default", stages: stages, jobSlug: "001-my-task")

        #expect(body != nil)
        #expect(body?.contains("This is the task body.") == true)
        #expect(body?.contains("multiple lines") == true)
    }

    @Test func nextJobNumberIncrementsMaxAcrossStages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        let doneDir = pipelineDir.appendingPathComponent("done")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: doneDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: A\n---\n".write(to: backlogDir.appendingPathComponent("003-task-a.md"), atomically: true, encoding: .utf8)
        try "---\ntitle: B\n---\n".write(to: doneDir.appendingPathComponent("005-task-b.md"), atomically: true, encoding: .utf8)

        let stages = [
            PipelineStageDef(name: "Backlog", type: .manual),
            PipelineStageDef(name: "Done", type: .manual)
        ]
        let next = PipelineReader.nextJobNumber(repoRoot: tempDir.path, pipelineName: "default", stages: stages)
        #expect(next == 6)
    }

    @Test func listsPipelinesInRepo() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let base = tempDir.appendingPathComponent(".hootty/pipeline")
        let featureDir = base.appendingPathComponent("feature")
        let bugsDir = base.appendingPathComponent("bugs")
        try FileManager.default.createDirectory(at: featureDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bugsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Only directories with pipeline.yaml count
        try "name: Feature\nstages:\n  - name: Backlog\n    type: manual\n".write(
            to: featureDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8
        )
        try "name: Bugs\nstages:\n  - name: Triage\n    type: manual\n".write(
            to: bugsDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8
        )

        let pipelines = PipelineReader.listPipelines(repoRoot: tempDir.path)
        #expect(pipelines == ["bugs", "feature"])
    }
}

// MARK: - PipelineWriter Tests

struct PipelineWriterTests {
    @Test func movesJobBetweenStages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        let implementDir = pipelineDir.appendingPathComponent("implement")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: implementDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: My Task\n---\n".write(
            to: backlogDir.appendingPathComponent("001-my-task.md"), atomically: true, encoding: .utf8
        )

        let result = PipelineWriter.moveJob(
            repoRoot: tempDir.path, pipelineName: "default",
            jobSlug: "001-my-task", fromStageDir: "backlog", toStageDir: "implement"
        )
        #expect(result == true)

        // File should be gone from backlog
        let backlogFiles = try FileManager.default.contentsOfDirectory(atPath: backlogDir.path)
        #expect(backlogFiles.isEmpty)

        // File should exist in implement
        let implementFiles = try FileManager.default.contentsOfDirectory(atPath: implementDir.path)
        #expect(implementFiles.contains("001-my-task.md"))
    }

    @Test func addsJobStubFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let slug = PipelineWriter.addJob(
            repoRoot: tempDir.path, pipelineName: "default",
            title: "Fix Login Bug", stageDir: "backlog", number: 7
        )
        #expect(slug != nil)
        #expect(slug?.hasPrefix("007-") == true)

        // Verify file exists and has frontmatter
        let files = try FileManager.default.contentsOfDirectory(atPath: backlogDir.path)
        #expect(files.count == 1)

        let filePath = backlogDir.appendingPathComponent(files[0])
        let content = try String(contentsOf: filePath, encoding: .utf8)
        #expect(content.contains("title: Fix Login Bug"))
    }

    @Test func removesJobFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: Doomed\n---\n".write(
            to: stageDir.appendingPathComponent("001-doomed.md"), atomically: true, encoding: .utf8
        )

        let result = PipelineWriter.removeJob(
            repoRoot: tempDir.path, pipelineName: "default",
            jobSlug: "001-doomed", stageDir: "backlog"
        )
        #expect(result == true)

        let files = try FileManager.default.contentsOfDirectory(atPath: stageDir.path)
        #expect(files.isEmpty)
    }

    @Test func togglesPauseState() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline")
        try FileManager.default.createDirectory(at: pipelineDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write initial state
        let initialState = """
        {
          "pipelines": {
            "default": {
              "claims": {},
              "job_statuses": {},
              "paused": false
            }
          }
        }
        """
        try initialState.write(to: pipelineDir.appendingPathComponent(".state.json"), atomically: true, encoding: .utf8)

        // Toggle to paused
        let result1 = PipelineWriter.togglePause(repoRoot: tempDir.path, pipelineName: "default")
        #expect(result1 == true)

        let state1 = PipelineReader.readStateFile(repoRoot: tempDir.path)
        #expect(state1?.pipelines["default"]?.paused == true)

        // Toggle back to unpaused
        let result2 = PipelineWriter.togglePause(repoRoot: tempDir.path, pipelineName: "default")
        #expect(result2 == true)

        let state2 = PipelineReader.readStateFile(repoRoot: tempDir.path)
        #expect(state2?.pipelines["default"]?.paused == false)
    }
}

@MainActor
struct PipelineModelTests {
    @Test func refreshPopulatesClaimsForMatchingPanes() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write pipeline config
        let yaml = """
        name: "Test"

        stages:
          - name: Backlog
            type: manual
          - name: Done
            type: manual
        """
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)

        // Write job file
        try "---\ntitle: My Job\n---\n".write(
            to: backlogDir.appendingPathComponent("001-my-job.md"),
            atomically: true, encoding: .utf8
        )

        // Write state file
        let paneID = UUID()
        let stateJSON = """
        {
          "pipelines": {
            "default": {
              "claims": { "\(paneID.uuidString)": "001-my-job" },
              "job_statuses": { "001-my-job": "active" },
              "paused": false
            }
          }
        }
        """
        try stateJSON.write(
            to: tempDir.appendingPathComponent(".hootty/pipeline/.state.json"),
            atomically: true, encoding: .utf8
        )

        let model = PipelineModel()
        model.refresh(
            repoRoot: tempDir.path,
            panes: [(id: paneID, sessionIDs: [paneID.uuidString])]
        )

        let claim = model.claimInfo(for: paneID)
        #expect(claim != nil)
        #expect(claim?.jobTitle == "My Job")
        #expect(claim?.pipelineName == "default")
        #expect(claim?.currentStageIndex == 0)
        #expect(claim?.stages.count == 2)
        #expect(claim?.status == .active)
    }

    @Test func refreshBuildsBoardData() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        let implementDir = pipelineDir.appendingPathComponent("implement")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: implementDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = """
        name: "Test"

        stages:
          - name: Backlog
            type: manual
          - name: Implement
            type: automated
        """
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)

        try "---\ntitle: Unclaimed Job\n---\n".write(to: backlogDir.appendingPathComponent("001-unclaimed.md"), atomically: true, encoding: .utf8)
        try "---\ntitle: Claimed Job\n---\n".write(to: implementDir.appendingPathComponent("002-claimed.md"), atomically: true, encoding: .utf8)

        let paneID = UUID()
        let stateJSON = """
        {
          "pipelines": {
            "default": {
              "claims": { "\(paneID.uuidString)": "002-claimed" },
              "job_statuses": { "002-claimed": "active" },
              "paused": false
            }
          }
        }
        """
        try stateJSON.write(to: tempDir.appendingPathComponent(".hootty/pipeline/.state.json"), atomically: true, encoding: .utf8)

        let model = PipelineModel()
        model.refresh(repoRoot: tempDir.path, panes: [(id: paneID, sessionIDs: [paneID.uuidString])])

        let boards = model.boardData(for: tempDir.path)
        #expect(boards.count == 1)

        let board = boards[0]
        #expect(board.displayName == "Test")
        #expect(board.stages.count == 2)
        #expect(board.jobs.count == 2)

        let grouped = board.jobsByStage
        #expect(grouped[0].count == 1) // Backlog
        #expect(grouped[1].count == 1) // Implement

        let unclaimed = grouped[0][0]
        #expect(unclaimed.title == "Unclaimed Job")
        #expect(unclaimed.claimedBy == nil)
        #expect(unclaimed.status == nil)

        let claimed = grouped[1][0]
        #expect(claimed.title == "Claimed Job")
        #expect(claimed.claimedBy == paneID.uuidString)
        #expect(claimed.status == .active)
    }

    @Test func refreshClearsClaimsWhenNoMatch() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent(".hootty/pipeline"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = PipelineModel()
        let paneID = UUID()

        // No state file — should clear
        model.refresh(
            repoRoot: tempDir.path,
            panes: [(id: paneID, sessionIDs: [paneID.uuidString])]
        )
        #expect(model.claimInfo(for: paneID) == nil)
    }

    @Test func attentionCountTracksManualStageJobs() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        let implementDir = pipelineDir.appendingPathComponent("implement")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: implementDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = """
        name: "Test"

        stages:
          - name: Backlog
            type: manual
          - name: Implement
            type: automated
        """
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)

        // Unclaimed job in manual stage → needs attention
        try "---\ntitle: Waiting\n---\n".write(to: backlogDir.appendingPathComponent("001-waiting.md"), atomically: true, encoding: .utf8)
        // Active job in automated stage → no attention
        try "---\ntitle: Working\n---\n".write(to: implementDir.appendingPathComponent("002-working.md"), atomically: true, encoding: .utf8)

        let paneID = UUID()
        let stateJSON = """
        {
          "pipelines": {
            "default": {
              "claims": { "\(paneID.uuidString)": "002-working" },
              "job_statuses": { "002-working": "active" },
              "paused": false
            }
          }
        }
        """
        try stateJSON.write(to: tempDir.appendingPathComponent(".hootty/pipeline/.state.json"), atomically: true, encoding: .utf8)

        let model = PipelineModel()
        model.refresh(repoRoot: tempDir.path, panes: [(id: paneID, sessionIDs: [paneID.uuidString])])

        #expect(model.attentionCount(for: tempDir.path) == 1)
    }

    @Test func interruptedTransitionFiresCallback() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineDir = tempDir.appendingPathComponent(".hootty/pipeline/default")
        let backlogDir = pipelineDir.appendingPathComponent("backlog")
        try FileManager.default.createDirectory(at: backlogDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = "name: \"Test\"\n\nstages:\n  - name: Backlog\n    type: manual\n"
        try yaml.write(to: pipelineDir.appendingPathComponent("pipeline.yaml"), atomically: true, encoding: .utf8)
        try "---\ntitle: Job\n---\n".write(to: backlogDir.appendingPathComponent("001-job.md"), atomically: true, encoding: .utf8)

        let paneID = UUID()
        let model = PipelineModel()
        var interruptedPaneID: UUID?
        model.onPaneInterrupted = { id in interruptedPaneID = id }

        // First refresh: active
        let activeJSON = """
        { "pipelines": { "default": { "claims": { "\(paneID.uuidString)": "001-job" }, "job_statuses": { "001-job": "active" }, "paused": false } } }
        """
        try activeJSON.write(to: tempDir.appendingPathComponent(".hootty/pipeline/.state.json"), atomically: true, encoding: .utf8)
        model.refresh(repoRoot: tempDir.path, panes: [(id: paneID, sessionIDs: [paneID.uuidString])])
        #expect(interruptedPaneID == nil)

        // Second refresh: interrupted
        let interruptedJSON = """
        { "pipelines": { "default": { "claims": { "\(paneID.uuidString)": "001-job" }, "job_statuses": { "001-job": "interrupted" }, "paused": false } } }
        """
        try interruptedJSON.write(to: tempDir.appendingPathComponent(".hootty/pipeline/.state.json"), atomically: true, encoding: .utf8)
        model.refresh(repoRoot: tempDir.path, panes: [(id: paneID, sessionIDs: [paneID.uuidString])])
        #expect(interruptedPaneID == paneID)
    }
}

// MARK: - PipelineWriter Extended Tests

struct PipelineWriterExtendedTests {
    @Test func appendsLogEntry() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: Test Job\n---\n\nSome body.\n".write(
            to: stageDir.appendingPathComponent("001-test-job.md"), atomically: true, encoding: .utf8
        )

        let stages = [PipelineStageDef(name: "Backlog", type: .manual)]
        let result = PipelineWriter.appendLogEntry(
            repoRoot: tempDir.path, pipelineName: "default",
            jobSlug: "001-test-job", stages: stages, message: "Test log entry"
        )
        #expect(result == true)

        let content = try String(contentsOf: stageDir.appendingPathComponent("001-test-job.md"), encoding: .utf8)
        #expect(content.contains("## Log"))
        #expect(content.contains("Test log entry"))
    }

    @Test func updatesJobTitle() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "---\ntitle: Old Title\npriority: high\n---\n\nBody.\n".write(
            to: stageDir.appendingPathComponent("001-test.md"), atomically: true, encoding: .utf8
        )

        let stages = [PipelineStageDef(name: "Backlog", type: .manual)]
        let result = PipelineWriter.updateJobTitle(
            repoRoot: tempDir.path, pipelineName: "default",
            jobSlug: "001-test", stages: stages, newTitle: "New Title"
        )
        #expect(result == true)

        let content = try String(contentsOf: stageDir.appendingPathComponent("001-test.md"), encoding: .utf8)
        #expect(content.contains("title: New Title"))
        #expect(!content.contains("Old Title"))
        #expect(content.contains("priority: high"))
    }

    @Test func createsPipelineWithStages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineBase = tempDir.appendingPathComponent(".hootty/pipeline")
        try FileManager.default.createDirectory(at: pipelineBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stages = PipelineTemplate.review.stages
        let result = PipelineWriter.createPipeline(
            repoRoot: tempDir.path, pipelineName: "feature",
            displayName: "Feature Pipeline", stages: stages
        )
        #expect(result == true)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "feature")
        #expect(config?.name == "Feature Pipeline")
        #expect(config?.stages.count == 4)

        // Stage directories exist
        let fm = FileManager.default
        let pipelineDir = pipelineBase.appendingPathComponent("feature")
        #expect(fm.fileExists(atPath: pipelineDir.appendingPathComponent("backlog").path))
        #expect(fm.fileExists(atPath: pipelineDir.appendingPathComponent("implement").path))
        #expect(fm.fileExists(atPath: pipelineDir.appendingPathComponent("review").path))
        #expect(fm.fileExists(atPath: pipelineDir.appendingPathComponent("done").path))

        // State file has entry
        let state = PipelineReader.readStateFile(repoRoot: tempDir.path)
        #expect(state?.pipelines["feature"] != nil)
    }

    @Test func deletesPipeline() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineBase = tempDir.appendingPathComponent(".hootty/pipeline")
        try FileManager.default.createDirectory(at: pipelineBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stages = PipelineTemplate.simple.stages
        _ = PipelineWriter.createPipeline(repoRoot: tempDir.path, pipelineName: "todelete", displayName: "Delete Me", stages: stages)

        let result = PipelineWriter.deletePipeline(repoRoot: tempDir.path, pipelineName: "todelete")
        #expect(result == true)

        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: pipelineBase.appendingPathComponent("todelete").path))
    }

    @Test func addsStage() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineBase = tempDir.appendingPathComponent(".hootty/pipeline")
        try FileManager.default.createDirectory(at: pipelineBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = PipelineWriter.createPipeline(repoRoot: tempDir.path, pipelineName: "default", displayName: "Test", stages: PipelineTemplate.simple.stages)

        let result = PipelineWriter.addStage(repoRoot: tempDir.path, pipelineName: "default", stageName: "Review", type: .manual, afterIndex: 1)
        #expect(result == true)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "default")
        #expect(config?.stages.count == 4)
        #expect(config?.stages[2].name == "Review")
        #expect(config?.stages[2].type == .manual)
    }

    @Test func removesStageAndMovesJobs() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineBase = tempDir.appendingPathComponent(".hootty/pipeline")
        try FileManager.default.createDirectory(at: pipelineBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = PipelineWriter.createPipeline(repoRoot: tempDir.path, pipelineName: "default", displayName: "Test", stages: PipelineTemplate.review.stages)

        // Add a job to Implement stage
        let implementDir = pipelineBase.appendingPathComponent("default/implement")
        try "---\ntitle: A Job\n---\n".write(to: implementDir.appendingPathComponent("001-a-job.md"), atomically: true, encoding: .utf8)

        // Remove Implement stage (index 1) → jobs move to Backlog (index 0)
        let result = PipelineWriter.removeStage(repoRoot: tempDir.path, pipelineName: "default", stageIndex: 1)
        #expect(result == true)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "default")
        #expect(config?.stages.count == 3)
        #expect(config?.stages.map(\.name) == ["Backlog", "Review", "Done"])

        // Job should be in backlog now
        let backlogFiles = try FileManager.default.contentsOfDirectory(atPath: pipelineBase.appendingPathComponent("default/backlog").path)
        #expect(backlogFiles.contains("001-a-job.md"))
    }

    @Test func changesStageType() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipelineBase = tempDir.appendingPathComponent(".hootty/pipeline")
        try FileManager.default.createDirectory(at: pipelineBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = PipelineWriter.createPipeline(repoRoot: tempDir.path, pipelineName: "default", displayName: "Test", stages: PipelineTemplate.simple.stages)

        let result = PipelineWriter.changeStageType(repoRoot: tempDir.path, pipelineName: "default", stageIndex: 1, newType: .manual)
        #expect(result == true)

        let config = PipelineReader.readPipelineConfig(repoRoot: tempDir.path, pipelineName: "default")
        #expect(config?.stages[1].type == .manual)
    }
}

// MARK: - PipelineReader Extended Tests

struct PipelineReaderExtendedTests {
    @Test func readsFullJobContent() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageDir = tempDir.appendingPathComponent(".hootty/pipeline/default/backlog")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let content = """
        ---
        title: Full Content Job
        ---

        The prompt body.

        ## Research

        Found some stuff.

        ## Log

        - Entry 1
        """
        try content.write(to: stageDir.appendingPathComponent("001-full.md"), atomically: true, encoding: .utf8)

        let stages = [PipelineStageDef(name: "Backlog", type: .manual)]
        let result = PipelineReader.readFullJobContent(repoRoot: tempDir.path, pipelineName: "default", stages: stages, jobSlug: "001-full")

        #expect(result != nil)
        #expect(result?.contains("## Research") == true)
        #expect(result?.contains("## Log") == true)
        #expect(result?.contains("The prompt body.") == true)
    }
}

// MARK: - PipelineState Tests (Templates & Attention)

struct PipelineTemplateTests {
    @Test func allTemplatesHaveStages() {
        for template in PipelineTemplate.allCases {
            #expect(!template.stages.isEmpty)
            #expect(!template.displayName.isEmpty)
        }
    }

    @Test func boardDataComputesAttentionCount() {
        let stages = [
            PipelineStageDef(name: "Backlog", type: .manual),
            PipelineStageDef(name: "Implement", type: .automated),
            PipelineStageDef(name: "Review", type: .manual)
        ]

        let jobs = [
            PipelineJobInfo(slug: "001", title: "A", stageIndex: 0, stageName: "Backlog", status: nil, claimedBy: nil),
            PipelineJobInfo(slug: "002", title: "B", stageIndex: 1, stageName: "Implement", status: .active, claimedBy: "sess"),
            PipelineJobInfo(slug: "003", title: "C", stageIndex: 2, stageName: "Review", status: .interrupted, claimedBy: nil)
        ]

        let board = PipelineBoardData(pipelineName: "test", displayName: "Test", stages: stages, jobs: jobs, isPaused: false)

        // 001 in manual stage with nil status → needs attention
        // 002 in automated stage → no attention
        // 003 in manual stage with interrupted status → needs attention
        #expect(board.jobsNeedingAttention == 2)
    }
}
