import Foundation

/// Aggregated attention state counts over a collection of panes.
/// Centralizes the counting logic and focus-exclusion rule.
public struct AttentionCounts: Equatable, Sendable {
    public let thinking: Int
    public let flagged: Int
    public let done: Int
    public let bell: Int
    public let error: Int

    public static let zero = AttentionCounts(thinking: 0, flagged: 0, done: 0, bell: 0, error: 0)

    public var hasAny: Bool {
        thinking > 0 || flagged > 0 || done > 0 || bell > 0 || error > 0
    }

    /// First non-nil attention kind from the counted (unfocused) panes.
    public var firstAttentionKind: AttentionKind? {
        if error > 0 { return .error }
        if done > 0 { return .done }
        if bell > 0 { return .bell }
        return nil
    }

    public init(thinking: Int, flagged: Int, done: Int, bell: Int, error: Int) {
        self.thinking = thinking
        self.flagged = flagged
        self.done = done
        self.bell = bell
        self.error = error
    }

    /// Count attention states across panes. Thinking and flagged count all panes;
    /// done, bell, and error exclude the focused pane (attention on the focused pane is
    /// cleared on interaction, so it shouldn't contribute to badges).
    @MainActor
    public init(panes: [Pane], focusedPaneID: UUID?) {
        var thinking = 0
        var flagged = 0
        var done = 0
        var bell = 0
        var error = 0
        for pane in panes {
            if pane.isThinking { thinking += 1 }
            if pane.isFlagged { flagged += 1 }
            guard pane.id != focusedPaneID else { continue }
            switch pane.attentionKind {
            case .bell: bell += 1
            case .done: done += 1
            case .error: error += 1
            case nil: break
            }
        }
        self.thinking = thinking
        self.flagged = flagged
        self.done = done
        self.bell = bell
        self.error = error
    }

    public static func + (lhs: AttentionCounts, rhs: AttentionCounts) -> AttentionCounts {
        AttentionCounts(
            thinking: lhs.thinking + rhs.thinking,
            flagged: lhs.flagged + rhs.flagged,
            done: lhs.done + rhs.done,
            bell: lhs.bell + rhs.bell,
            error: lhs.error + rhs.error
        )
    }
}
