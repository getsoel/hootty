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

    @Test func bellSetsAttentionOnAnyPane() {
        let (handler, _, pane) = makeHandler()
        let didSet = handler.handleBell(pane.id)
        #expect(didSet)
        #expect(pane.attentionKind == .bell)
    }

    @Test func bellSuppressedDuringThinking() {
        let (handler, _, pane) = makeHandler()
        handler.handlePaneThinkingChanged(pane.id, isThinking: true)
        let didSet = handler.handleBell(pane.id)
        #expect(!didSet)
        #expect(pane.attentionKind == nil)
    }

    @Test func bellNotBlockedByNote() {
        let (handler, _, pane) = makeHandler()
        pane.setNote("remember this")
        let didSet = handler.handleBell(pane.id)
        #expect(didSet)
        #expect(pane.attentionKind == .bell)
        #expect(pane.hasNote)
    }

    // MARK: - Thinking

    @Test func thinkingStartClearsAttention() {
        let (handler, _, pane) = makeHandler()
        pane.attentionKind = .bell
        handler.handlePaneThinkingChanged(pane.id, isThinking: true)
        #expect(pane.isThinking)
        #expect(pane.attentionKind == nil)
    }

    @Test func thinkingStartClearsAttentionWithNote() {
        let (handler, _, pane) = makeHandler()
        pane.attentionKind = .bell
        pane.setNote("remember this")
        handler.handlePaneThinkingChanged(pane.id, isThinking: true)
        #expect(pane.isThinking)
        #expect(pane.attentionKind == nil)
        #expect(pane.hasNote)
    }

    @Test func thinkingStopSetsDoneOnUnfocusedPane() throws {
        let (handler, ws, p1, _) = try makeHandlerWithSplit()
        // p1 is unfocused (p2 is focused after split)
        handler.handlePaneThinkingChanged(p1.id, isThinking: true)
        handler.handlePaneThinkingChanged(p1.id, isThinking: false)
        #expect(!p1.isThinking)
        #expect(p1.attentionKind == .done)
    }

    @Test func thinkingStopNoDoneOnFocusedPane() throws {
        let (handler, _, _, p2) = try makeHandlerWithSplit()
        // p2 is focused
        handler.handlePaneThinkingChanged(p2.id, isThinking: true)
        handler.handlePaneThinkingChanged(p2.id, isThinking: false)
        #expect(!p2.isThinking)
        #expect(p2.attentionKind == nil)
    }

    // MARK: - Attention

    @Test func attentionIgnoredOnFocusedPane() {
        let (handler, _, pane) = makeHandler()
        // Single pane is focused
        let didSet = handler.handlePaneNeedsAttention(pane.id, kind: .bell)
        #expect(!didSet)
        #expect(pane.attentionKind == nil)
    }

    @Test func attentionSetOnUnfocusedPane() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        let didSet = handler.handlePaneNeedsAttention(p1.id, kind: .bell)
        #expect(didSet)
        #expect(p1.attentionKind == .bell)
    }

    @Test func attentionNotBlockedByNote() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        p1.setNote("remember this")
        let didSet = handler.handlePaneNeedsAttention(p1.id, kind: .bell)
        #expect(didSet)
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

    @Test func unmatchedTitlePreservesAgentSessionMarker() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        #expect(pane.agentSessionID == Pane.autoSessionID)
        // Transition to a non-agent-looking title (Codex idle pattern).
        handler.handleTitleChange(pane.id, title: "my-project")
        // Session marker is preserved — clearing is deferred to processDidExit.
        #expect(pane.agentSessionID == Pane.autoSessionID)
        // Thinking is ended (implicit idle).
        #expect(!pane.isThinking)
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
        #expect(p1.attentionKind == .done)
    }

    @Test func geminiNeedsAttentionDoesNotFireWhenFocused() throws {
        let (handler, _, _, p2) = try makeHandlerWithSplit()
        // p2 is focused. Send Gemini "Action Required" (✋).
        handler.handleTitleChange(p2.id, title: "\u{270B}  Action Required (my-folder)")
        #expect(p2.agentSessionID == Pane.autoSessionID)
        #expect(!p2.isThinking)
        #expect(p2.attentionKind == nil)
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
        let didSet = handler.handleBell(UUID())
        #expect(!didSet)
    }
}
