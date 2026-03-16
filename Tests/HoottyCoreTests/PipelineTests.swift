import Foundation
import PipelineKit
import Testing
@testable import HoottyCore

// MARK: - PipelineModel Tests

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

// MARK: - PipelineState Display Types Tests

struct PipelineTemplateTests {
    @Test func allTemplatesHaveStages() {
        for template in PipelineTemplate.allCases {
            #expect(!template.stages.isEmpty)
            #expect(!template.displayName.isEmpty)
        }
    }

    @Test func boardDataComputesAttentionCount() {
        let stages = [
            Stage(name: "Backlog", type: .manual),
            Stage(name: "Implement", type: .automated),
            Stage(name: "Review", type: .manual)
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
