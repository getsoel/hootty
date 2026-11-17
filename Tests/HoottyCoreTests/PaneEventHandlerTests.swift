import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct PaneEventHandlerTests {
    private func makeHandler() -> (PaneEventHandler, Workspace, Pane) {
        let ws = Workspace(name: "Test")
        let pane = ws.allPanes[0]
        var selectedWSID: UUID? = ws.id
        let handler = PaneEventHandler(
            findPane: { id in
                guard let p = ws.findPane(id: id) else { return nil }
                return (ws, p)
            },
            selectedWorkspaceID: { selectedWSID },
            debouncedSave: {}
        )
        return (handler, ws, pane)
    }

    private func makeHandlerWithSplit() throws -> (PaneEventHandler, Workspace, Pane, Pane) {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))
        // p2 is now focused, p1 is unfocused
        var selectedWSID: UUID? = ws.id
        let handler = PaneEventHandler(
            findPane: { id in
                guard let p = ws.findPane(id: id) else { return nil }
                return (ws, p)
            },
            selectedWorkspaceID: { selectedWSID },
            debouncedSave: {}
        )
        return (handler, ws, p1, p2)
    }

    // MARK: - Bell

    @Test func bellSetsAttentionOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        #expect(handler.handleBell(p1.id) == .bell)
        #expect(p1.attentionKind == .bell)
    }

    @Test func bellIgnoredOnFocusedPane() {
        // The user is looking at it: nothing was missed.
        let (handler, _, pane) = makeHandler()
        #expect(handler.handleBell(pane.id) == nil)
        #expect(pane.attentionKind == nil)
    }

    @Test func bellSuppressedDuringThinking() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        #expect(handler.handleBell(p1.id) == nil)
        #expect(p1.attentionKind == nil)
    }

    @Test func bellNotBlockedByNote() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        p1.setNote("remember this")
        #expect(handler.handleBell(p1.id) == .bell)
        #expect(p1.attentionKind == .bell)
        #expect(p1.hasNote)
    }

    // MARK: - Thinking

    @Test func thinkingStartClearsAttention() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleBell(p1.id)
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        #expect(p1.isThinking)
        #expect(p1.attentionKind == nil)
    }

    @Test func thinkingStartClearsAttentionWithNote() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleBell(p1.id)
        p1.setNote("remember this")
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        #expect(p1.isThinking)
        #expect(p1.attentionKind == nil)
        #expect(p1.hasNote)
    }

    @Test func thinkingStopSetsDoneOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        // p1 is unfocused (p2 is focused after split)
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        #expect(handler.handleHoottyPresence(p1.id, presence: .idle) == .done)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .done)
    }

    @Test func thinkingStopNoDoneOnFocusedPane() throws {
        let (handler, _, _, p2) = try makeHandlerWithSplit()
        // p2 is focused
        handler.handleHoottyPresence(p2.id, presence: .thinking)
        #expect(handler.handleHoottyPresence(p2.id, presence: .idle) == nil)
        #expect(!p2.isThinking)
        #expect(p2.attentionKind == nil)
    }

    // MARK: - Notifications

    @Test func notificationIgnoredOnFocusedPane() {
        let (handler, _, pane) = makeHandler()
        // Single pane is focused
        #expect(handler.handleNotification(pane.id) == nil)
        #expect(pane.attentionKind == nil)
    }

    @Test func notificationSetOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        #expect(handler.handleNotification(p1.id) == .bell)
        #expect(p1.attentionKind == .bell)
    }

    @Test func notificationNotBlockedByNote() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        p1.setNote("remember this")
        #expect(handler.handleNotification(p1.id) == .bell)
        #expect(p1.attentionKind == .bell)
        #expect(p1.hasNote)
    }

    // MARK: - Title-Based Agent Detection (Claude)

    @Test func claudeTitleSetsAutoSession() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        #expect(pane.agentSessionID == Pane.autoSessionID)
        #expect(pane.isThinking)
    }

    @Test func claudeIdleSetsThinkingFalse() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        handler.handleTitleChange(pane.id, title: "✳ project-name")
        #expect(!pane.isThinking)
    }

    // MARK: - Implicit Idle (Codex has no idle glyph)

    @Test func unmatchedTitleFromThinkingPreservesAgentSessionMarker() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        #expect(pane.agentSessionID == Pane.autoSessionID)
        // Transition to a non-agent-looking title (Codex idle pattern).
        handler.handleTitleChange(pane.id, title: "my-project")
        // Session marker is preserved — first unmatched title after thinking
        // is treated as implicit idle, not exit.
        #expect(pane.agentSessionID == Pane.autoSessionID)
        // Thinking is ended (implicit idle).
        #expect(!pane.isThinking)
    }

    @Test func unmatchedTitleAfterIdleClearsAgentSessionMarker() {
        let (handler, _, pane) = makeHandler()
        // Agent thinking → idle (implicit, e.g. Codex).
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        handler.handleTitleChange(pane.id, title: "my-project")
        #expect(pane.agentSessionID == Pane.autoSessionID)
        #expect(!pane.isThinking)
        // Agent process exits, shell emits a new non-agent title.
        handler.handleTitleChange(pane.id, title: "zsh")
        // Session marker is cleared so sidebar reverts to terminal style.
        #expect(pane.agentSessionID == nil)
    }

    @Test func claudeExitClearsAgentSessionMarker() {
        let (handler, _, pane) = makeHandler()
        // Claude thinking → idle (✳ glyph matches as idle).
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        handler.handleTitleChange(pane.id, title: "✳ project-name")
        #expect(pane.agentSessionID == Pane.autoSessionID)
        #expect(!pane.isThinking)
        // Claude exits; shell takes over and emits a non-agent title.
        handler.handleTitleChange(pane.id, title: "/Users/me/project")
        #expect(pane.agentSessionID == nil)
    }

    @Test func codexImplicitIdleFiresDoneWhenUnfocused() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        // p1 is unfocused. Simulate Codex thinking → idle.
        handler.handleTitleChange(p1.id, title: "\u{280B} hootty")
        #expect(p1.isThinking)
        #expect(p1.agentSessionID == Pane.autoSessionID)
        // Codex idle: title collapses to plain project name.
        handler.handleTitleChange(p1.id, title: "hootty")
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .done)
        #expect(p1.agentSessionID == Pane.autoSessionID)
    }

    @Test func nonAgentPaneIgnoresUnmatchedTitles() {
        let (handler, _, pane) = makeHandler()
        // Pane has never been detected as an agent.
        handler.handleTitleChange(pane.id, title: "vim main.swift")
        #expect(pane.agentSessionID == nil)
        #expect(!pane.isThinking)
    }

    // MARK: - Gemini needsAttention Focus Gating

    @Test func geminiNeedsAttentionFiresWhenUnfocused() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        // p1 is unfocused. Send Gemini "Action Required" (✋).
        handler.handleTitleChange(p1.id, title: "\u{270B}  Action Required (my-folder)")
        #expect(p1.agentSessionID == Pane.autoSessionID)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .blocked)
    }

    @Test func geminiNeedsAttentionShowsWhenFocused() throws {
        // Blocked is live state: the hand stays while the user looks at it.
        let (handler, _, _, p2) = try makeHandlerWithSplit()
        // p2 is focused. Send Gemini "Action Required" (✋).
        handler.handleTitleChange(p2.id, title: "\u{270B}  Action Required (my-folder)")
        #expect(p2.agentSessionID == Pane.autoSessionID)
        #expect(!p2.isThinking)
        #expect(p2.attentionKind == .blocked)
    }

    // MARK: - Gemini Thinking / Idle

    @Test func geminiFourPointedStarSetsThinking() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{2726}  Working…")
        #expect(pane.agentSessionID == Pane.autoSessionID)
        #expect(pane.isThinking)
    }

    @Test func geminiDiamondSetsIdle() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{2726}  Working…")
        handler.handleTitleChange(pane.id, title: "\u{25C7}  Ready (my-folder)")
        #expect(!pane.isThinking)
    }

    @Test func unknownPaneIsNoOp() {
        let (handler, _, _) = makeHandler()
        #expect(handler.handleBell(UUID()) == nil)
    }

    // MARK: - Hootty Protocol: Presence

    @Test func hoottyThinkingSetsAgentSessionAndThinking() {
        let (handler, _, pane) = makeHandler()
        handler.handleHoottyPresence(pane.id, presence: .thinking)
        #expect(pane.agentSessionID == Pane.autoSessionID)
        #expect(pane.isThinking)
        #expect(pane.attentionKind == nil)
    }

    @Test func hoottyThinkingClearsExistingAttention() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleBell(p1.id)
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        #expect(p1.isThinking)
        #expect(p1.attentionKind == nil)
    }

    @Test func hoottyIdleEndsThinking() {
        let (handler, _, pane) = makeHandler()
        handler.handleHoottyPresence(pane.id, presence: .thinking)
        handler.handleHoottyPresence(pane.id, presence: .idle)
        #expect(!pane.isThinking)
    }

    @Test func hoottyIdleSetsDoneOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        handler.handleHoottyPresence(p1.id, presence: .idle)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .done)
    }

    @Test func hoottyAttentionSetsBlockedOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleHoottyPresence(p1.id, presence: .needsAttention)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .blocked)
    }

    @Test func hoottyAttentionShowsOnFocusedPane() throws {
        let (handler, _, _, p2) = try makeHandlerWithSplit()
        #expect(handler.handleHoottyPresence(p2.id, presence: .needsAttention) == .blocked)
        #expect(p2.attentionKind == .blocked)
    }

    // MARK: - Progress Reports (OSC 9;4)

    @Test func progressReportIgnoredOnNonAgentPane() {
        let (handler, _, pane) = makeHandler()
        handler.handleProgressReport(pane.id, isBusy: true)
        // A package manager's progress bar must not turn a shell into an agent pane.
        #expect(pane.agentSessionID == nil)
        #expect(!pane.isThinking)
    }

    @Test func progressReportSetsThinkingOnAgentPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        p1.agentSessionID = Pane.autoSessionID
        handler.handleBell(p1.id)
        handler.handleProgressReport(p1.id, isBusy: true)
        #expect(p1.isThinking)
        #expect(p1.attentionKind == nil)
    }

    @Test func progressReportEndsThinkingOnAgentPane() {
        let (handler, _, pane) = makeHandler()
        pane.agentSessionID = Pane.autoSessionID
        handler.handleProgressReport(pane.id, isBusy: true)
        handler.handleProgressReport(pane.id, isBusy: false)
        #expect(!pane.isThinking)
    }

    @Test func progressReportIdleSetsDoneOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        p1.agentSessionID = Pane.autoSessionID
        handler.handleProgressReport(p1.id, isBusy: true)
        handler.handleProgressReport(p1.id, isBusy: false)
        #expect(p1.attentionKind == .done)
    }

    @Test func progressReportRemoveBeforeAnyWorkIsInert() {
        // Claude Code emits 9;4;0 at startup, before the first turn.
        let (handler, _, pane) = makeHandler()
        pane.agentSessionID = Pane.autoSessionID
        handler.handleProgressReport(pane.id, isBusy: false)
        #expect(!pane.isThinking)
        #expect(pane.attentionKind == nil)
    }

    // MARK: - Hootty Protocol: Error

    @Test func hoottyErrorSetsErrorAttention() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        #expect(handler.handleHoottyError(p1.id) == .error)
        #expect(p1.agentSessionID == Pane.autoSessionID)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .error)
    }

    @Test func hoottyErrorOnFocusedPaneIsNotAnUnseenEvent() {
        let (handler, _, pane) = makeHandler()
        #expect(handler.handleHoottyError(pane.id) == nil)
        #expect(pane.agentSessionID == Pane.autoSessionID)
        #expect(pane.attentionKind == nil)
    }

    @Test func hoottyErrorClearsThinking() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleHoottyPresence(p1.id, presence: .thinking)
        handler.handleHoottyError(p1.id)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .error)
    }

    // MARK: - Attention priority

    @Test func bellDoesNotHideBlocked() throws {
        // Claude rings the bell at a permission prompt right after the hook
        // raises the hand; the hand must stay.
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleHoottyPresence(p1.id, presence: .needsAttention)
        #expect(handler.handleBell(p1.id) == nil)
        #expect(p1.attentionKind == .blocked)
        #expect(p1.presence.unseen == nil)
    }

    @Test func notificationDoesNotHideBlocked() throws {
        // A plain OSC 9 notification ("Claude needs your permission") arrives as .bell.
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleHoottyPresence(p1.id, presence: .needsAttention)
        #expect(handler.handleNotification(p1.id) == nil)
        #expect(p1.attentionKind == .blocked)
    }

    @Test func strongerAttentionReplacesWeakerNotTheReverse() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        #expect(handler.handleBell(p1.id) == .bell)
        #expect(handler.handleProgramStatus(p1.id, report: ProgramStatusReport(state: .done)) == .done)
        #expect(handler.handleBell(p1.id) == nil)
        #expect(p1.attentionKind == .done)
        #expect(handler.handleProgramStatus(p1.id, report: ProgramStatusReport(state: .blocked)) == .blocked)
        #expect(p1.attentionKind == .blocked)
    }

    @Test func programStatusMovesFromBlockedToDone() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        handler.handleProgramStatus(p1.id, report: ProgramStatusReport(state: .blocked, kind: .permission))
        #expect(p1.attentionKind == .blocked)
        #expect(handler.handleProgramStatus(p1.id, report: ProgramStatusReport(state: .done)) == .done)
        #expect(p1.attentionKind == .done)
    }
}
