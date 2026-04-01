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

    @Test func bellSuppressedWhenFlagged() {
        let (handler, _, pane) = makeHandler()
        pane.attentionKind = .flag
        let didSet = handler.handleBell(pane.id)
        #expect(!didSet)
        #expect(pane.attentionKind == .flag)
    }

    // MARK: - Thinking

    @Test func thinkingStartClearsAttention() {
        let (handler, _, pane) = makeHandler()
        pane.attentionKind = .bell
        handler.handlePaneThinkingChanged(pane.id, isThinking: true)
        #expect(pane.isThinking)
        #expect(pane.attentionKind == nil)
    }

    @Test func thinkingStartDoesNotClearFlag() {
        let (handler, _, pane) = makeHandler()
        pane.attentionKind = .flag
        handler.handlePaneThinkingChanged(pane.id, isThinking: true)
        #expect(pane.isThinking)
        #expect(pane.attentionKind == .flag)
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

    @Test func attentionBlockedByFlag() throws {
        let (handler, _, p1, _) = try makeHandlerWithSplit()
        p1.attentionKind = .flag
        let didSet = handler.handlePaneNeedsAttention(p1.id, kind: .bell)
        #expect(!didSet)
        #expect(p1.attentionKind == .flag)
    }

    // MARK: - Title-Based Claude Detection

    @Test func claudeTitleSetsAutoSession() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        #expect(pane.claudeSessionID == "auto")
        #expect(pane.isThinking)
    }

    @Test func nonClaudeTitleClearsAutoSession() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        #expect(pane.claudeSessionID == "auto")
        handler.handleTitleChange(pane.id, title: "zsh")
        #expect(pane.claudeSessionID == nil)
        #expect(!pane.isThinking)
    }

    @Test func claudeIdleSetsThinkingFalse() {
        let (handler, _, pane) = makeHandler()
        handler.handleTitleChange(pane.id, title: "\u{280B} Thinking…")
        handler.handleTitleChange(pane.id, title: "✳ project-name")
        #expect(!pane.isThinking)
    }

    @Test func unknownPaneIsNoOp() {
        let (handler, _, _) = makeHandler()
        let didSet = handler.handleBell(UUID())
        #expect(!didSet)
    }
}
