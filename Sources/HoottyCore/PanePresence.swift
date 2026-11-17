import Foundation

/// What the program in a pane is doing right now.
public enum PaneActivity: Equatable, Sendable {
    case idle
    case working(progress: Int?)
    /// Can't continue until the user acts. `kind` is nil when the source can't say why.
    case blocked(ProgramStatusKind?)

    public var isWorking: Bool {
        if case .working = self { return true }
        return false
    }

    public var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }

    /// Completion (0–100) while working, when the program reports it.
    public var progress: Int? {
        if case let .working(progress) = self { return progress }
        return nil
    }

    /// Working or blocked: positive evidence the program is active, which a
    /// less trusted source may assert over an older signal (see `PanePresence.activity`).
    var isActive: Bool {
        self != .idle
    }
}

/// Something that happened in a pane that bears on its presence.
public enum PresenceEvent: Equatable, Sendable {
    /// Agent title glyph changed. nil: the title no longer matches any agent.
    case title(AgentPresence?)
    /// `hootty:presence:` from the agent hook scripts.
    case hook(AgentPresence)
    /// `hootty:presence:error` from the agent hook scripts.
    case hookError
    /// OSC 9;4 progress (only routed for panes already known to run an agent).
    case progressReport(isBusy: Bool)
    /// OSC 7501 program status report.
    case programStatus(ProgramStatusReport)
    /// Terminal bell (BEL).
    case bell
    /// A desktop notification (OSC 9/777) that isn't a hootty protocol message.
    case notification
    /// The shell is back at its prompt: whatever was running has ended.
    case commandFinished
    /// The user looked at the pane (focused, clicked or typed in it).
    case viewed
}

/// The presence of a pane, as a pure value: what each source last said,
/// plus events the user hasn't seen. Everything the UI shows is computed from
/// this, so the display never depends on which signal happened to arrive last.
///
/// Two layers:
/// - **Live activity** (idle / working / blocked) is a state. It ends only when
///   a source reports something new or the command finishes, never because
///   the user looked. A blocked pane keeps its hand while focused.
/// - **Unseen events** (done / error / bell) are notifications. They're raised
///   only while the pane isn't focused and cleared when the user views it.
///   A weaker event never replaces a stronger one (`AttentionKind.priority`).
public struct PanePresence: Equatable, Sendable {
    /// One source's latest activity and when it arrived (`sequence`).
    public struct Signal: Equatable, Sendable {
        public var activity: PaneActivity
        public var sequence: Int
    }

    /// Fallback sources, most trusted first.
    public enum FallbackSource: CaseIterable, Sendable {
        case hook, title, progressReport
    }

    public private(set) var programStatus = ProgramStatusRecords()
    /// The command that sent the OSC 7501 records has finished. Its leftover
    /// done/error records still describe results, but no longer decide live
    /// activity (they'd otherwise hide whatever runs next).
    public private(set) var programEnded = false
    public private(set) var hook: Signal?
    public private(set) var title: Signal?
    public private(set) var progressReport: Signal?
    /// The strongest event the user hasn't seen. Never `.blocked`: that's live activity.
    public private(set) var unseen: AttentionKind?
    private var sequence = 0

    public init() {}

    /// Build a presence directly, e.g. every combination in tests. Sequences
    /// in the given signals set which source spoke most recently.
    init(
        programStatus: ProgramStatusRecords = ProgramStatusRecords(),
        programEnded: Bool = false,
        hook: Signal? = nil,
        title: Signal? = nil,
        progressReport: Signal? = nil,
        unseen: AttentionKind? = nil
    ) {
        self.programStatus = programStatus
        self.programEnded = programEnded
        self.hook = hook
        self.title = title
        self.progressReport = progressReport
        self.unseen = unseen
        self.sequence = [hook, title, progressReport].compactMap { $0?.sequence }.max() ?? 0
    }

    // MARK: - Derived state

    /// Resolved live activity, or nil when no source has anything to say.
    ///
    /// OSC 7501 is a complete protocol, so while it has records it decides
    /// alone. Otherwise the most trusted fallback that has a signal decides,
    /// except that a *newer* working/blocked signal from a less trusted source
    /// wins: it is positive evidence the program moved on (e.g. Claude's title
    /// spinner resuming after a permission prompt, which no hook reports). An
    /// idle signal never overrides, because idle glyphs are ambiguous: Claude's
    /// title shows ✳ while a permission prompt is open.
    public var activity: PaneActivity? {
        if !programEnded, let fromProgram = programStatus.activity { return fromProgram }
        let ranked = FallbackSource.allCases.map { signal(for: $0) }
        guard let baseIndex = ranked.firstIndex(where: { $0 != nil }), let base = ranked[baseIndex] else {
            return nil
        }
        let newerActive = ranked[(baseIndex + 1)...]
            .compactMap { $0 }
            .filter { $0.activity.isActive && $0.sequence > base.sequence }
            .max { $0.sequence < $1.sequence }
        return newerActive?.activity ?? base.activity
    }

    public var isWorking: Bool {
        activity?.isWorking ?? false
    }

    /// What the attention indicator shows: blocked while the program waits,
    /// otherwise the strongest unseen event.
    public var attention: AttentionKind? {
        activity?.isBlocked == true ? .blocked : unseen
    }

    /// Whether `.viewed` would change anything.
    public var hasUnseen: Bool {
        unseen != nil || programStatus.hasFinished
    }

    public func signal(for source: FallbackSource) -> Signal? {
        switch source {
        case .hook: hook
        case .title: title
        case .progressReport: progressReport
        }
    }

    // MARK: - Transitions

    /// Apply an event. `isFocused` is whether the user is looking at the pane
    /// (its workspace is selected and it is the focused pane).
    ///
    /// Returns the attention kind to announce (play a sound for), if any:
    /// `.blocked` when the pane starts waiting on the user, or the unseen
    /// event just raised. Repeating a state announces nothing.
    @discardableResult
    public mutating func apply(_ event: PresenceEvent, isFocused: Bool) -> AttentionKind? {
        let before = activity
        var raised: [AttentionKind] = []

        switch event {
        case let .title(glyph):
            if let glyph {
                set(\.title, glyph.activity(blockedKind: nil))
                resolveOlderBlocked(by: .title)
            } else if title?.activity.isWorking == true {
                // No idle glyph (e.g. Codex): leaving the spinner means idle.
                set(\.title, .idle)
            } else {
                title = nil
            }
        case let .hook(presence):
            // The hook's attention signal fires only on a permission prompt.
            set(\.hook, presence.activity(blockedKind: .permission))
        case .hookError:
            set(\.hook, .idle)
            // While OSC 7501 reports, the program announces its own errors.
            if programStatus.isEmpty { raised.append(.error) }
        case let .progressReport(isBusy):
            set(\.progressReport, isBusy ? .working(progress: nil) : .idle)
            resolveOlderBlocked(by: .progressReport)
        case let .programStatus(report):
            let previous = programStatus[report.id]?.state
            programStatus.apply(report)
            programEnded = false
            if report.state != previous {
                if report.state == .done { raised.append(.done) }
                if report.state == .error { raised.append(.error) }
            }
        case .bell:
            // Agents ring the bell mid-turn and at prompts: while the program
            // is working or blocked it adds nothing the indicator doesn't show.
            if before?.isActive != true { raised.append(.bell) }
        case .notification:
            // "Needs your permission" duplicates a blocked hand.
            if before?.isBlocked != true { raised.append(.bell) }
        case .commandFinished:
            hook = nil
            title = nil
            progressReport = nil
            programStatus.dropTransient()
            programEnded = true
        case .viewed:
            unseen = nil
            if programEnded {
                programStatus.acknowledgeFinished()
            } else {
                programStatus.markFinishedSeen()
            }
            return nil
        }

        let after = activity
        // A turn ended: the program was active and now isn't (idle or gone).
        if before?.isActive == true, after?.isActive != true {
            raised.append(.done)
        }
        // A new turn supersedes whatever the last one left unseen.
        if after?.isWorking == true, before?.isWorking != true {
            unseen = nil
        }

        var announce: AttentionKind?
        if after?.isBlocked == true, before?.isBlocked != true {
            announce = .blocked
        }
        if !isFocused, let event = raised.max(by: { $0.priority < $1.priority }) {
            if unseen.map({ event.priority >= $0.priority }) ?? true {
                unseen = event
                if announce == nil { announce = event }
            }
        }
        return announce
    }

    /// Working evidence from `source` answers an older blocked signal from a
    /// more trusted source: the program resumed (e.g. Claude's spinner after a
    /// permission prompt is approved, which no hook reports). Without this the
    /// stale hand would come back when the spinner stops at the end of the turn.
    private mutating func resolveOlderBlocked(by source: FallbackSource) {
        guard let evidence = signal(for: source), evidence.activity.isWorking else { return }
        for trusted in FallbackSource.allCases.prefix(while: { $0 != source }) {
            let slot = Self.keyPath(for: trusted)
            if let stale = self[keyPath: slot], stale.activity.isBlocked, stale.sequence < evidence.sequence {
                self[keyPath: slot] = Signal(activity: .working(progress: nil), sequence: stale.sequence)
            }
        }
    }

    private static func keyPath(for source: FallbackSource) -> WritableKeyPath<PanePresence, Signal?> {
        switch source {
        case .hook: \.hook
        case .title: \.title
        case .progressReport: \.progressReport
        }
    }

    private mutating func set(_ slot: WritableKeyPath<PanePresence, Signal?>, _ activity: PaneActivity) {
        // Same activity again (e.g. every spinner frame): keep the original
        // sequence so "newer" means "changed more recently".
        guard self[keyPath: slot]?.activity != activity else { return }
        sequence += 1
        self[keyPath: slot] = Signal(activity: activity, sequence: sequence)
    }
}

extension AgentPresence {
    func activity(blockedKind: ProgramStatusKind?) -> PaneActivity {
        switch self {
        case .thinking: .working(progress: nil)
        case .idle: .idle
        case .needsAttention: .blocked(blockedKind)
        }
    }
}
