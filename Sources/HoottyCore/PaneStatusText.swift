import Foundation

/// The words shown for a pane's presence, kept out of the views so the rules
/// are testable. Layout never depends on them: the sidebar row stays one line
/// whatever the program says.
///
/// - `badge`: a few characters after the pane name in the sidebar ("40%",
///   "permission"). Only the details worth acting on; idle shows nothing.
/// - `message`: the live line for the pane's tab bar, which is wide enough
///   for a sentence ("Reading PaneEventHandler.swift").
/// - `tooltip`: everything, one fact per line, for hovering the sidebar row.
public struct PaneStatusText: Equatable, Sendable {
    public var badge: String?
    public var message: String?
    public var tooltip: String?

    public init(badge: String? = nil, message: String? = nil, tooltip: String? = nil) {
        self.badge = badge
        self.message = message
        self.tooltip = tooltip
    }

    /// - Parameters:
    ///   - agentName: Fallback program name when OSC 7501 gives no `app`.
    ///   - since: When the live activity last changed (for "Idle since").
    public init(presence: PanePresence, agentName: String?, since: Date?) {
        guard let activity = presence.activity else {
            // Nothing live. A finished command may still have unseen results.
            self.message = Self.resultLine(presence.programStatus)
            self.tooltip = message
            return
        }
        let records = presence.programStatus
        let root = records[""]
        let detail = root.flatMap { $0.msg ?? $0.title }
        let app = records.effectiveApp(for: "") ?? agentName

        let headline: String
        switch activity {
        case let .working(progress):
            self.badge = progress.map { "\($0)%" }
            headline = progress.map { "Working \($0)%" } ?? "Working"
            self.message = detail
        case let .blocked(kind):
            self.badge = Self.kindWord(kind)
            headline = Self.blockedHeadline(kind)
            let blockedDetail = records.all.last { $0.state == .blocked }.flatMap { $0.msg ?? $0.title }
            self.message = blockedDetail.map { "\(headline): \($0)" } ?? headline
        case .idle:
            headline = since.map { "Idle since \(Self.timeFormatter.string(from: $0))" } ?? "Idle"
            self.message = Self.resultLine(records)
        }

        var lines = [[app, headline].compactMap { $0 }.joined(separator: " · ")]
        if let detail, !activity.isBlocked { lines.append(detail) }
        if activity.isBlocked, let message, message != headline { lines.append(message) }
        for record in records.all where !record.id.isEmpty {
            lines.append(Self.recordLine(record))
        }
        self.tooltip = lines.joined(separator: "\n")
    }

    // MARK: - Wording

    static func kindWord(_ kind: ProgramStatusKind?) -> String {
        switch kind {
        case .permission: "permission"
        case .question: "question"
        case .auth: "login"
        case nil: "waiting"
        }
    }

    static func blockedHeadline(_ kind: ProgramStatusKind?) -> String {
        switch kind {
        case .permission: "Needs permission"
        case .question: "Has a question"
        case .auth: "Needs login"
        case nil: "Waiting on you"
        }
    }

    /// "Done: msg" / "Failed: msg" for a finished root record, if any.
    private static func resultLine(_ records: ProgramStatusRecords) -> String? {
        guard let root = records[""], root.state == .done || root.state == .error else { return nil }
        let label = root.state == .done ? "Done" : "Failed"
        return (root.msg ?? root.title).map { "\(label): \($0)" } ?? label
    }

    private static func recordLine(_ record: ProgramStatusReport) -> String {
        let name = record.title ?? record.id
        let state: String = switch record.state {
        case .working: record.progress.map { "working \($0)%" } ?? "working"
        case .blocked: blockedHeadline(record.kind).lowercased()
        case .done: "done"
        case .error: "failed"
        case .idle, .clear: "idle"
        }
        return [name + ": " + state, record.msg].compactMap { $0 }.joined(separator: " — ")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
