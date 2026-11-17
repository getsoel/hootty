import Foundation
import Testing
@testable import HoottyCore

struct PaneStatusTextTests {
    private func presence(_ events: [PresenceEvent]) -> PanePresence {
        var presence = PanePresence()
        for event in events {
            presence.apply(event, isFocused: false)
        }
        return presence
    }

    private func report(_ body: String) throws -> ProgramStatusReport {
        try #require(ProgramStatusReport.parse(body))
    }

    @Test func noPresenceShowsNothing() {
        let text = PaneStatusText(presence: PanePresence(), agentName: nil, since: nil)
        #expect(text == PaneStatusText())
    }

    @Test func workingWithProgressAndMessage() throws {
        // msg = "Reading Pane.swift"
        let text = try PaneStatusText(
            presence: presence([.programStatus(report("state=working:app=claude-code:progress=40:msg=UmVhZGluZyBQYW5lLnN3aWZ0"))]),
            agentName: nil, since: nil
        )
        #expect(text.badge == "40%")
        #expect(text.message == "Reading Pane.swift")
        #expect(text.tooltip == "claude-code · Working 40%\nReading Pane.swift")
    }

    @Test func workingWithoutDetailHasNoBadgeOrMessage() {
        // Hooks and titles carry no progress or text: the spinner says it all.
        let text = PaneStatusText(presence: presence([.hook(.thinking)]), agentName: "claude", since: nil)
        #expect(text.badge == nil)
        #expect(text.message == nil)
        #expect(text.tooltip == "claude · Working")
    }

    @Test(arguments: [
        (ProgramStatusKind.permission, "permission", "Needs permission"),
        (.question, "question", "Has a question"),
        (.auth, "login", "Needs login"),
    ])
    func blockedKinds(kind: ProgramStatusKind, badge: String, headline: String) {
        let text = PaneStatusText(
            presence: presence([.programStatus(ProgramStatusReport(state: .blocked, kind: kind))]),
            agentName: nil, since: nil
        )
        #expect(text.badge == badge)
        #expect(text.message == headline)
    }

    @Test func blockedFromHookIsPermissionAndFromTitleIsWaiting() {
        #expect(PaneStatusText(presence: presence([.hook(.needsAttention)]), agentName: nil, since: nil).badge == "permission")
        #expect(PaneStatusText(presence: presence([.title(.needsAttention)]), agentName: nil, since: nil).badge == "waiting")
    }

    @Test func idleIsQuietInTheRow() throws {
        let since = try #require(ISO8601DateFormatter().date(from: "2026-11-17T10:42:00Z"))
        let text = PaneStatusText(presence: presence([.hook(.thinking), .hook(.idle)]), agentName: "claude", since: since)
        #expect(text.badge == nil)
        #expect(text.message == nil)
        #expect(text.tooltip?.hasPrefix("claude · Idle since ") == true)
    }

    @Test func finishedResultShowsUntilSeen() throws {
        // msg = "3 regions"
        var state = try presence([.programStatus(report("state=working")), .programStatus(report("state=done:msg=MyByZWdpb25z"))])
        #expect(PaneStatusText(presence: state, agentName: nil, since: nil).message == "Done: 3 regions")
        state.apply(.commandFinished, isFocused: false)
        #expect(PaneStatusText(presence: state, agentName: nil, since: nil).message == "Done: 3 regions")
        state.apply(.viewed, isFocused: true)
        #expect(PaneStatusText(presence: state, agentName: nil, since: nil).message == nil)
    }

    @Test func childRecordsAppearInTooltip() {
        let text = PaneStatusText(presence: presence([
            .programStatus(ProgramStatusReport(state: .working, app: "deploy")),
            .programStatus(ProgramStatusReport(id: "eu-west", state: .blocked, kind: .auth)),
            .programStatus(ProgramStatusReport(id: "us-east", state: .working, progress: 60, title: "US East"))
        ]), agentName: nil, since: nil)
        #expect(text.badge == "login")
        #expect(text.tooltip == "deploy · Needs login\neu-west: needs login\nUS East: working 60%")
    }
}
