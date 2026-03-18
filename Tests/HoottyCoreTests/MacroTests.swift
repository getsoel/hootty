import Foundation
import Testing
@testable import HoottyCore

// MARK: - Macro Parsing Tests

struct MacroParsingTests {
    @Test func parsesValidMacroFile() {
        let content = """
        name: Review Flow
        steps:
          - /simplify
          - /reflect
          - "Check for TODO comments"
        """
        let result = parseMacroFile(content)
        #expect(result != nil)
        #expect(result?.name == "Review Flow")
        #expect(result?.steps.count == 3)
        #expect(result?.steps[0] == "/simplify")
        #expect(result?.steps[1] == "/reflect")
        #expect(result?.steps[2] == "Check for TODO comments")
    }

    @Test func parsesUnquotedSteps() {
        let content = """
        name: Simple
        steps:
          - /test
          - Run the linter and fix issues
        """
        let result = parseMacroFile(content)
        #expect(result != nil)
        #expect(result?.steps.count == 2)
        #expect(result?.steps[1] == "Run the linter and fix issues")
    }

    @Test func returnsNilForEmptySteps() {
        let content = """
        name: Empty
        steps:
        """
        #expect(parseMacroFile(content) == nil)
    }

    @Test func returnsNilForMissingName() {
        let content = """
        steps:
          - /test
        """
        #expect(parseMacroFile(content) == nil)
    }

    @Test func ignoresCommentsAndBlankLines() {
        let content = """
        # This is a macro
        name: Commented

        steps:
          # first step
          - /step1

          - /step2
        """
        let result = parseMacroFile(content)
        #expect(result != nil)
        #expect(result?.steps.count == 2)
    }
}

// MARK: - MacroRunner Tests

@MainActor
struct MacroRunnerTests {
    @Test func startReturnFirstStep() {
        let runner = MacroRunner()
        let macro = Macro(id: "test", name: "Test", steps: ["/step1", "/step2"])
        let first = runner.start(macro: macro, paneID: UUID())
        #expect(first == "/step1")
    }

    @Test func stepCompletedAdvancesToNextStep() {
        let runner = MacroRunner()
        let paneID = UUID()
        let macro = Macro(id: "test", name: "Test", steps: ["/step1", "/step2", "/step3"])
        _ = runner.start(macro: macro, paneID: paneID)

        let second = runner.stepCompleted(paneID: paneID)
        #expect(second == "/step2")

        let third = runner.stepCompleted(paneID: paneID)
        #expect(third == "/step3")
    }

    @Test func stepCompletedReturnsNilWhenDone() {
        let runner = MacroRunner()
        let paneID = UUID()
        let macro = Macro(id: "test", name: "Test", steps: ["/step1"])
        _ = runner.start(macro: macro, paneID: paneID)

        let next = runner.stepCompleted(paneID: paneID)
        #expect(next == nil)
    }

    @Test func progressTracksState() {
        let runner = MacroRunner()
        let paneID = UUID()
        let macro = Macro(id: "test", name: "Test Macro", steps: ["/a", "/b"])
        _ = runner.start(macro: macro, paneID: paneID)

        let p1 = runner.progress(paneID: paneID)
        #expect(p1?.macroName == "Test Macro")
        #expect(p1?.currentStep == 0)
        #expect(p1?.totalSteps == 2)
        #expect(p1?.currentStepText == "/a")
        #expect(p1?.isComplete == false)

        _ = runner.stepCompleted(paneID: paneID)
        let p2 = runner.progress(paneID: paneID)
        #expect(p2?.currentStep == 1)
        #expect(p2?.currentStepText == "/b")

        _ = runner.stepCompleted(paneID: paneID)
        let p3 = runner.progress(paneID: paneID)
        #expect(p3?.isComplete == true)
    }

    @Test func removeCleansMacroWhileRunning() {
        let runner = MacroRunner()
        let paneID = UUID()
        let macro = Macro(id: "test", name: "Test", steps: ["/a", "/b"])
        _ = runner.start(macro: macro, paneID: paneID)

        runner.remove(paneID: paneID)
        #expect(runner.isActive(paneID: paneID) == false)
        #expect(runner.progress(paneID: paneID) == nil)
    }

    @Test func removeCleansMacroWhenComplete() {
        let runner = MacroRunner()
        let paneID = UUID()
        let macro = Macro(id: "test", name: "Test", steps: ["/a"])
        _ = runner.start(macro: macro, paneID: paneID)
        _ = runner.stepCompleted(paneID: paneID)

        runner.remove(paneID: paneID)
        #expect(runner.isActive(paneID: paneID) == false)
    }

    @Test func multiplePanesIndependent() {
        let runner = MacroRunner()
        let pane1 = UUID()
        let pane2 = UUID()
        let macro1 = Macro(id: "m1", name: "Macro 1", steps: ["/a", "/b"])
        let macro2 = Macro(id: "m2", name: "Macro 2", steps: ["/x"])

        _ = runner.start(macro: macro1, paneID: pane1)
        _ = runner.start(macro: macro2, paneID: pane2)

        #expect(runner.isActive(paneID: pane1) == true)
        #expect(runner.isActive(paneID: pane2) == true)

        _ = runner.stepCompleted(paneID: pane2)
        #expect(runner.progress(paneID: pane2)?.isComplete == true)
        #expect(runner.progress(paneID: pane1)?.isComplete == false)
    }

    @Test func stepCompletedIgnoresUnknownPane() {
        let runner = MacroRunner()
        let result = runner.stepCompleted(paneID: UUID())
        #expect(result == nil)
    }

    @Test func startWithEmptyStepsReturnsNil() {
        let runner = MacroRunner()
        let macro = Macro(id: "empty", name: "Empty", steps: [])
        let result = runner.start(macro: macro, paneID: UUID())
        #expect(result == nil)
    }
}

// MARK: - MacroStore Tests

@MainActor
struct MacroStoreTests {
    @Test func refreshReadsMacroFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let macroDir = tempDir.appendingPathComponent(".hootty/macros")
        try FileManager.default.createDirectory(at: macroDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = """
        name: Test Flow
        steps:
          - /step1
          - /step2
        """
        try yaml.write(
            to: macroDir.appendingPathComponent("test-flow.yaml"),
            atomically: true, encoding: .utf8
        )

        let store = MacroStore()
        store.refresh(repoRoot: tempDir.path)

        #expect(store.macros.count == 1)
        #expect(store.macros[0].id == "test-flow")
        #expect(store.macros[0].name == "Test Flow")
        #expect(store.macros[0].steps == ["/step1", "/step2"])
    }

    @Test func refreshHandlesMissingDirectory() {
        let store = MacroStore()
        store.refresh(repoRoot: "/nonexistent/path")
        #expect(store.macros.isEmpty)
    }

    @Test func hasMacrosDetectsDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let macroDir = tempDir.appendingPathComponent(".hootty/macros")
        try FileManager.default.createDirectory(at: macroDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(MacroStore.hasMacros(repoRoot: tempDir.path) == true)
        #expect(MacroStore.hasMacros(repoRoot: "/nonexistent") == false)
    }

    @Test func refreshSortsAlphabetically() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let macroDir = tempDir.appendingPathComponent(".hootty/macros")
        try FileManager.default.createDirectory(at: macroDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "name: Zebra\nsteps:\n  - /z".write(
            to: macroDir.appendingPathComponent("zebra.yaml"),
            atomically: true, encoding: .utf8
        )
        try "name: Alpha\nsteps:\n  - /a".write(
            to: macroDir.appendingPathComponent("alpha.yaml"),
            atomically: true, encoding: .utf8
        )

        let store = MacroStore()
        store.refresh(repoRoot: tempDir.path)

        #expect(store.macros.count == 2)
        #expect(store.macros[0].id == "alpha")
        #expect(store.macros[1].id == "zebra")
    }
}
