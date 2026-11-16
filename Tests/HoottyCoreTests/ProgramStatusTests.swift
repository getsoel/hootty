import Foundation
import Testing
@testable import HoottyCore

struct ProgramStatusTests {
    // MARK: - Parsing

    @Test func parsesClaudeCodeReport() throws {
        // As emitted by Claude Code 2.1.312's OSC 7501 encoder.
        let report = try #require(ProgramStatusReport.parse(
            "state=blocked:app=claude-code:id=agent/1:kind=question:progress=40:title=VGVzdHM:msg=V2hpY2ggYnJhbmNoPw=="
        ))
        #expect(report == ProgramStatusReport(
            id: "agent/1", state: .blocked, kind: .question, progress: 40,
            app: "claude-code", title: "Tests", msg: "Which branch?"
        ))
    }

    @Test func missingOrUnknownStateIsIgnored() {
        #expect(ProgramStatusReport.parse("app=cargo") == nil)
        #expect(ProgramStatusReport.parse("state=sleeping") == nil)
        #expect(ProgramStatusReport.parse("") == nil)
    }

    @Test func forgivingAboutPairsLastValueWins() throws {
        let report = try #require(ProgramStatusReport.parse(" state = idle :future=yes:oops:state=working"))
        #expect(report.state == .working)
    }

    @Test func keysOnlyApplyToTheirStates() throws {
        let done = try #require(ProgramStatusReport.parse("state=done:kind=auth:progress=50"))
        #expect(done.kind == nil)
        #expect(done.progress == nil)
        let working = try #require(ProgramStatusReport.parse("state=working:progress=101"))
        #expect(working.progress == nil)
    }

    @Test func textWithControlCharactersIsDropped() throws {
        // "a\nb" and an RTL override are not allowed in msg.
        let newline = try #require(ProgramStatusReport.parse("state=idle:msg=YQpi"))
        #expect(newline.msg == nil)
        let bidi = try #require(ProgramStatusReport.parse("state=idle:msg=4oCuZXZpbA"))
        #expect(bidi.msg == nil)
    }

    // MARK: - Records

    @Test func clearRemovesRecordAndChildren() {
        var records = ProgramStatusRecords()
        for id in ["", "deploy", "deploy/us-east", "deployer"] {
            records.apply(ProgramStatusReport(id: id, state: .working))
        }
        records.apply(ProgramStatusReport(id: "deploy", state: .clear))
        #expect(records.count == 2)
        #expect(records["deployer"] != nil)

        records.apply(ProgramStatusReport(state: .clear))
        #expect(records.isEmpty)
    }

    @Test func primaryIsMostUrgentRecord() {
        var records = ProgramStatusRecords()
        records.apply(ProgramStatusReport(state: .working, progress: 10))
        records.apply(ProgramStatusReport(id: "eu-west", state: .blocked, kind: .auth))
        records.apply(ProgramStatusReport(id: "us-east", state: .done))
        #expect(records.primary?.id == "eu-west")
        #expect(records.summary == "Needs login")
    }

    @Test func appIsInheritedFromAncestors() {
        var records = ProgramStatusRecords()
        records.apply(ProgramStatusReport(state: .working, app: "terraform"))
        records.apply(ProgramStatusReport(id: "plan/module", state: .working))
        #expect(records.effectiveApp(for: "plan/module") == "terraform")
    }

    @Test func leastRecentlyUpdatedRecordIsEvicted() {
        var records = ProgramStatusRecords()
        for index in 0 ... ProgramStatusRecords.maxRecords {
            records.apply(ProgramStatusReport(id: "job\(index)", state: .working))
        }
        #expect(records.count == ProgramStatusRecords.maxRecords)
        #expect(records["job0"] == nil)
    }

    @Test func acknowledgeDropsOnlyFinishedRecords() {
        var records = ProgramStatusRecords()
        records.apply(ProgramStatusReport(state: .working))
        records.apply(ProgramStatusReport(id: "a", state: .done))
        records.apply(ProgramStatusReport(id: "b", state: .error))
        records.acknowledgeFinished()
        #expect(records.count == 1)
        #expect(records[""]?.state == .working)
    }
}
