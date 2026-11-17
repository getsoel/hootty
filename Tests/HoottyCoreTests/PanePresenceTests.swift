import Foundation
import Testing
@testable import HoottyCore

/// Every state and every transition of `PanePresence`, checked against the
/// rules the display must always follow, plus recorded real-world sequences.
///
/// Layer 1 (`everyState`) and layer 2 (`everyEventInEveryState`) enumerate the
/// whole space instead of spelling out expected values by hand, so a rule that
/// breaks in any combination fails here. Layer 3 (`Scenarios`) replays what
/// agents actually send.
enum PresenceSpace {
    static let programStates: [ProgramStatusState?] = [nil, .idle, .working, .done, .blocked, .error]
    static let hookActivities: [PaneActivity?] = [nil, .idle, .working(progress: nil), .blocked(.permission)]
    static let titleActivities: [PaneActivity?] = [nil, .idle, .working(progress: nil), .blocked(nil)]
    static let progressActivities: [PaneActivity?] = [nil, .idle, .working(progress: nil)]
    static let unseenEvents: [AttentionKind?] = [nil, .bell, .done, .error]
    static let programEnded = [false, true]
    /// Which fallback spoke first, second, third (sequence numbers per source).
    static let orders: [[PanePresence.FallbackSource: Int]] = [
        [.hook: 1, .title: 2, .progressReport: 3], [.hook: 1, .title: 3, .progressReport: 2],
        [.hook: 2, .title: 1, .progressReport: 3], [.hook: 2, .title: 3, .progressReport: 1],
        [.hook: 3, .title: 1, .progressReport: 2], [.hook: 3, .title: 2, .progressReport: 1]
    ]

    static let events: [PresenceEvent] = [
        .title(.thinking), .title(.idle), .title(.needsAttention), .title(nil),
        .hook(.thinking), .hook(.idle), .hook(.needsAttention), .hookError,
        .progressReport(isBusy: true), .progressReport(isBusy: false)
    ] + ProgramStatusState.allCases.map { .programStatus(ProgramStatusReport(state: $0)) }
        + [.bell, .notification, .commandFinished, .viewed]

    /// Every combination of source values, orderings and unseen events.
    static let allStates: [PanePresence] = {
        var states: [PanePresence] = []
        for programState in programStates {
            var records = ProgramStatusRecords()
            if let programState { records.apply(ProgramStatusReport(state: programState)) }
            for ended in programEnded {
                // A finished command only leaves done/error records behind.
                if ended, programState != nil, programState != .done, programState != .error { continue }
                for hook in hookActivities {
                    for title in titleActivities {
                        for progress in progressActivities {
                            for order in orders {
                                for unseen in unseenEvents {
                                    states.append(PanePresence(
                                        programStatus: records,
                                        programEnded: ended,
                                        hook: hook.map { .init(activity: $0, sequence: order[.hook]!) },
                                        title: title.map { .init(activity: $0, sequence: order[.title]!) },
                                        progressReport: progress.map { .init(activity: $0, sequence: order[.progressReport]!) },
                                        unseen: unseen
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
        return states
    }()

    static func fallbacks(_ presence: PanePresence) -> [PanePresence.Signal] {
        PanePresence.FallbackSource.allCases.compactMap { presence.signal(for: $0) }
    }
}

extension PresenceEvent {
    /// The fallback slot this event writes, if it is a fallback-source event.
    var fallbackSource: PanePresence.FallbackSource? {
        switch self {
        case .title: .title
        case .hook, .hookError: .hook
        case .progressReport: .progressReport
        default: nil
        }
    }
}

struct PanePresenceStateTests {
    // MARK: - Layer 1: every state

    @Test func everyState() throws {
        for presence in PresenceSpace.allStates {
            let activity = presence.activity
            let fallbacks = PresenceSpace.fallbacks(presence)

            if !presence.programEnded, let fromProgram = presence.programStatus.activity {
                // OSC 7501 decides alone while its program runs and has records.
                #expect(activity == fromProgram, "\(presence)")
            } else if fallbacks.isEmpty {
                #expect(activity == nil, "\(presence)")
            } else {
                let base = fallbacks[0]
                let newest = try #require(fallbacks.max { $0.sequence < $1.sequence })
                // Idle never overrides: an idle result is the most trusted source's.
                if activity == .idle { #expect(base.activity == .idle, "\(presence)") }
                // The newest active signal is never ignored.
                if newest.activity != .idle { #expect(activity == newest.activity, "\(presence)") }
                // Without newer active evidence, the most trusted source decides.
                let newerActive = fallbacks.dropFirst().contains { $0.activity != .idle && $0.sequence > base.sequence }
                if !newerActive { #expect(activity == base.activity, "\(presence)") }
            }

            // Display follows from activity and unseen alone.
            #expect(presence.isWorking == (activity?.isWorking ?? false))
            if activity?.isBlocked == true {
                #expect(presence.attention == .blocked)
            } else {
                #expect(presence.attention == presence.unseen)
            }
            #expect(presence.unseen != .blocked)
        }
    }

    // MARK: - Layer 2: every event in every state

    @Test(arguments: PresenceSpace.events)
    func everyEventInEveryState(event: PresenceEvent) {
        for before in PresenceSpace.allStates {
            for isFocused in [false, true] {
                var after = before
                let announced = after.apply(event, isFocused: isFocused)
                let context = "\(event) focused=\(isFocused) from \(before)"

                // Isolation: an event touches only its own source, except that
                // working evidence resolves an older blocked from a more
                // trusted source (to working, keeping its sequence).
                for source in PanePresence.FallbackSource.allCases where source != event.fallbackSource {
                    guard event != .commandFinished else { continue }
                    let old = before.signal(for: source), new = after.signal(for: source)
                    if old != new {
                        #expect(old?.activity.isBlocked == true && new?.activity == .working(progress: nil)
                            && new?.sequence == old?.sequence, "\(context)")
                    }
                }
                if case .programStatus = event {} else if event != .commandFinished, event != .viewed {
                    #expect(after.programStatus == before.programStatus, "\(context)")
                }

                // Unseen events: never raised on the focused pane, never downgraded.
                if isFocused {
                    #expect(after.unseen == before.unseen || after.unseen == nil, "\(context)")
                }
                if let old = before.unseen, let new = after.unseen, old != new {
                    #expect(new.priority > old.priority, "\(context)")
                }

                // A turn that ends while unseen leaves an unseen event behind.
                if before.activity?.isActive == true, after.activity?.isActive != true, !isFocused, event != .viewed {
                    #expect(after.unseen != nil, "\(context)")
                }

                // Announcements: blocked exactly when the pane starts waiting;
                // anything else is the unseen event just raised, off-focus.
                let startedWaiting = after.activity?.isBlocked == true && before.activity?.isBlocked != true
                #expect((announced == .blocked) == startedWaiting, "\(context)")
                if let announced, announced != .blocked {
                    #expect(after.unseen == announced && !isFocused, "\(context)")
                }

                switch event {
                case .viewed:
                    // Looking clears what was missed, never the live state.
                    #expect(after.activity == before.activity, "\(context)")
                    #expect(after.unseen == nil && !after.programStatus.hasFinished, "\(context)")
                case .commandFinished:
                    #expect(PresenceSpace.fallbacks(after).isEmpty, "\(context)")
                    // Only done/error records survive the prompt (spec lifetime rule).
                    #expect(after.programStatus.activity?.isActive != true, "\(context)")
                case .bell where before.activity?.isActive == true,
                     .notification where before.activity?.isBlocked == true:
                    // Redundant with what the indicator already shows.
                    #expect(after == before, "\(context)")
                default:
                    break
                }

                // Live-state events are idempotent: repeating one changes nothing.
                let repeatable = switch event {
                case .title(nil), .hookError, .bell, .notification: false
                default: true
                }
                if repeatable {
                    var again = after
                    #expect(again.apply(event, isFocused: isFocused) == nil, "\(context)")
                    #expect(again == after, "\(context)")
                }
            }
        }
    }
}

// MARK: - Layer 3: recorded sequences

/// What agents actually send, in order. `focused` is whether the user is
/// looking at the pane when the event arrives.
@MainActor
struct PanePresenceScenarios {
    private struct Step {
        let event: PresenceEvent
        var focused = false
    }

    /// Replays steps on a fresh presence; returns the announcements in order.
    private func replay(_ steps: [Step], into presence: inout PanePresence) -> [AttentionKind] {
        steps.compactMap { presence.apply($0.event, isFocused: $0.focused) }
    }

    @Test func claudePermissionPromptViaHooksAndTitle() {
        var presence = PanePresence()
        // Turn starts, prompt opens: Claude rings the bell and posts a
        // notification right after the hook, and its title parks on ✳.
        let announced = replay([
            Step(event: .hook(.thinking)),
            Step(event: .title(.thinking)),
            Step(event: .progressReport(isBusy: true)),
            Step(event: .hook(.needsAttention)),
            Step(event: .title(.idle)),
            Step(event: .bell),
            Step(event: .notification)
        ], into: &presence)
        #expect(presence.attention == .blocked)
        #expect(announced == [.blocked], "one sound for the prompt, not a bell on top")

        // Approved: no hook fires, but the spinner resumes.
        replay([Step(event: .title(.thinking))], into: &presence)
        #expect(presence.isWorking)
        #expect(presence.attention == nil)

        // Turn ends (Stop hook): done, while the user is elsewhere.
        let end = replay([Step(event: .title(.idle)), Step(event: .hook(.idle)), Step(event: .progressReport(isBusy: false))], into: &presence)
        #expect(presence.attention == .done)
        #expect(end == [.done])
    }

    @Test func blockedHandStaysWhileLookingAtIt() {
        var presence = PanePresence()
        replay([Step(event: .hook(.thinking), focused: true), Step(event: .hook(.needsAttention), focused: true)], into: &presence)
        #expect(presence.attention == .blocked)
        // Clicking or typing in the pane doesn't answer the prompt.
        presence.apply(.viewed, isFocused: true)
        #expect(presence.attention == .blocked)
        // Answering it does: Claude resumes.
        presence.apply(.title(.thinking), isFocused: true)
        #expect(presence.attention == nil)
    }

    @Test func interruptAtPermissionPromptKeepsHandUntilNextPrompt() {
        // Known gap of the fallback channels: Esc at a prompt fires no hook,
        // and ✳/9;4-remove are idle signals that can't lower blocked. The hand
        // stays until the next prompt starts a turn. OSC 7501 has no such gap.
        var presence = PanePresence()
        replay([
            Step(event: .hook(.thinking)), Step(event: .title(.thinking)), Step(event: .progressReport(isBusy: true)),
            Step(event: .hook(.needsAttention)), Step(event: .title(.idle)),
            Step(event: .progressReport(isBusy: false), focused: true)
        ], into: &presence)
        #expect(presence.attention == .blocked)
        presence.apply(.hook(.thinking), isFocused: true)
        #expect(presence.isWorking)
    }

    @Test func codexHasNoIdleGlyph() {
        var presence = PanePresence()
        replay([Step(event: .title(.thinking)), Step(event: .title(nil))], into: &presence)
        #expect(presence.activity == .idle)
        #expect(presence.attention == .done)
        // A second unmatched title means Codex is gone.
        presence.apply(.title(nil), isFocused: false)
        #expect(presence.activity == nil)
    }

    @Test func geminiActionRequiredThenResumes() {
        var presence = PanePresence()
        let announced = replay([Step(event: .title(.thinking)), Step(event: .title(.needsAttention))], into: &presence)
        #expect(announced == [.blocked])
        presence.apply(.title(.thinking), isFocused: false)
        #expect(presence.isWorking)
        #expect(presence.attention == nil)
    }

    @Test func claudeOverProgramStatusIgnoresOlderChannels() {
        var presence = PanePresence()
        let announced = replay([
            Step(event: .programStatus(ProgramStatusReport(state: .working, app: "claude-code"))),
            Step(event: .hook(.thinking)), Step(event: .title(.thinking)),
            Step(event: .programStatus(ProgramStatusReport(state: .blocked, kind: .permission, app: "claude-code"))),
            // The fallbacks keep talking; 7501 alone decides.
            Step(event: .title(.idle)), Step(event: .hook(.needsAttention)), Step(event: .bell), Step(event: .hookError)
        ], into: &presence)
        #expect(presence.activity == .blocked(.permission))
        #expect(announced == [.blocked])

        presence.apply(.programStatus(ProgramStatusReport(state: .working, app: "claude-code")), isFocused: false)
        #expect(presence.isWorking)
        #expect(presence.apply(.programStatus(ProgramStatusReport(state: .idle, app: "claude-code")), isFocused: false) == .done)
        #expect(presence.attention == .done)
    }

    @Test func multiRecordDeploy() {
        var presence = PanePresence()
        replay([
            Step(event: .programStatus(ProgramStatusReport(state: .working, progress: 10, app: "deploy"))),
            Step(event: .programStatus(ProgramStatusReport(id: "eu-west", state: .blocked, kind: .auth)))
        ], into: &presence)
        #expect(presence.activity == .blocked(.auth))

        presence.apply(.programStatus(ProgramStatusReport(id: "eu-west", state: .clear)), isFocused: false)
        #expect(presence.activity == .working(progress: 10))

        presence.apply(.programStatus(ProgramStatusReport(state: .done)), isFocused: false)
        #expect(presence.attention == .done)
        // The shell prompt returns: the result stays until seen.
        presence.apply(.commandFinished, isFocused: false)
        #expect(presence.attention == .done)
        presence.apply(.viewed, isFocused: true)
        #expect(presence.attention == nil)
        #expect(presence.programStatus.isEmpty)
    }

    @Test func agentExitsMidTurn() {
        var presence = PanePresence()
        replay([Step(event: .hook(.thinking)), Step(event: .commandFinished)], into: &presence)
        #expect(presence.activity == nil)
        #expect(presence.attention == .done)
    }

    @Test func plainShellBell() {
        var unfocused = PanePresence()
        #expect(unfocused.apply(.bell, isFocused: false) == .bell)
        #expect(unfocused.attention == .bell)

        var focused = PanePresence()
        #expect(focused.apply(.bell, isFocused: true) == nil)
        #expect(focused.attention == nil)
    }
}
