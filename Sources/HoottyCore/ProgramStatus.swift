import Foundation

/// OSC 7501 program status protocol.
///
/// Spec: https://superlogical.com/rex/docs/build/program-status
///
/// A program writes `ESC ] 7501 ; state=working:app=cargo:progress=40 ST` to
/// say what it is doing. libghostty (with Hootty's patch, see
/// `patches/ghostty/`) validates each report against the spec's limits and
/// forwards the body after `7501;`. This file parses that body and keeps the
/// per-pane records; the terminal owns lifetime, not the program.
public enum ProgramStatusState: String, Sendable, CaseIterable {
    case idle, working, done, blocked, error, clear

    /// Precedence when several records compete for one pane indicator.
    var urgency: Int {
        switch self {
        case .blocked: 5
        case .error: 4
        case .working: 3
        case .done: 2
        case .idle: 1
        case .clear: 0
        }
    }
}

/// What a `blocked` program needs from the user.
public enum ProgramStatusKind: String, Sendable {
    case permission, question, auth
}

/// One OSC 7501 report. A report replaces its record completely.
public struct ProgramStatusReport: Equatable, Sendable {
    /// Record path, e.g. `deploy/us-east`. Empty means the root record.
    public var id: String
    public var state: ProgramStatusState
    public var kind: ProgramStatusKind?
    /// 0–100, or nil for indeterminate.
    public var progress: Int?
    public var app: String?
    public var title: String?
    public var msg: String?

    public init(
        id: String = "",
        state: ProgramStatusState,
        kind: ProgramStatusKind? = nil,
        progress: Int? = nil,
        app: String? = nil,
        title: String? = nil,
        msg: String? = nil
    ) {
        self.id = id
        self.state = state
        self.kind = kind
        self.progress = progress
        self.app = app
        self.title = title
        self.msg = msg
    }

    /// Parse a report body (`key=value` pairs joined by `:`). Returns nil when
    /// `state` is missing or unknown, as the spec requires. Malformed pairs and
    /// unknown keys are skipped; a repeated key keeps its last value.
    public static func parse(_ body: String) -> ProgramStatusReport? {
        var values: [String: String] = [:]
        for pair in body.split(separator: ":", omittingEmptySubsequences: true) {
            guard let eq = pair.firstIndex(of: "=") else { continue }
            let key = pair[..<eq].trimmingCharacters(in: .whitespaces)
            let value = pair[pair.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = value
        }
        guard let rawState = values["state"], let state = ProgramStatusState(rawValue: rawState) else {
            return nil
        }
        var report = ProgramStatusReport(id: values["id"] ?? "", state: state)
        if state == .blocked {
            report.kind = values["kind"].flatMap(ProgramStatusKind.init(rawValue:))
        }
        if state == .working || state == .blocked, let raw = values["progress"], let value = Int(raw),
           (0 ... 100).contains(value) {
            report.progress = value
        }
        report.app = values["app"].flatMap { $0.isEmpty ? nil : $0 }
        report.title = values["title"].flatMap(decodeText)
        report.msg = values["msg"].flatMap(decodeText)
        return report
    }

    /// Decode a base64 (padding optional) single line of text. Returns nil for
    /// invalid input or text with control characters, which the spec forbids.
    static func decodeText(_ encoded: String) -> String? {
        guard !encoded.isEmpty else { return nil }
        let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let hasControl = text.unicodeScalars.contains {
            $0.properties.generalCategory == .control || $0.properties.generalCategory == .format
        }
        return hasControl || text.isEmpty ? nil : text
    }
}

/// The program status records reported in one pane, keyed by record id.
public struct ProgramStatusRecords: Equatable, Sendable {
    /// Spec allows terminals to cap records (at least 64); least recently
    /// updated is evicted first.
    public static let maxRecords = 256

    private var records: [String: ProgramStatusReport] = [:]
    /// Ids in update order, oldest first, for eviction.
    private var updateOrder: [String] = []

    public init() {}

    public var isEmpty: Bool {
        records.isEmpty
    }

    public var count: Int {
        records.count
    }

    public subscript(id: String) -> ProgramStatusReport? {
        records[id]
    }

    /// Every record, least recently updated first.
    public var all: [ProgramStatusReport] {
        updateOrder.compactMap { records[$0] }
    }

    /// Apply a report: `clear` removes the record and its children (or every
    /// record when sent without an id); anything else replaces the record.
    public mutating func apply(_ report: ProgramStatusReport) {
        if report.state == .clear {
            if report.id.isEmpty {
                removeAll()
            } else {
                let childPrefix = report.id + "/"
                remove { id, _ in id == report.id || id.hasPrefix(childPrefix) }
            }
            return
        }
        records[report.id] = report
        updateOrder.removeAll { $0 == report.id }
        updateOrder.append(report.id)
        while records.count > Self.maxRecords, let oldest = updateOrder.first {
            updateOrder.removeFirst()
            records.removeValue(forKey: oldest)
        }
    }

    /// Lifetime rule for the attached process exiting or a new shell prompt:
    /// drop `working` and `blocked` (and `idle`, which the spec allows); keep
    /// `done` and `error` until the user has seen them.
    public mutating func dropTransient() {
        remove { _, record in record.state != .done && record.state != .error }
    }

    /// Whether any `done` or `error` record is waiting to be seen.
    public var hasFinished: Bool {
        records.values.contains { $0.state == .done || $0.state == .error }
    }

    /// The user has seen the results but the program is still running: keep
    /// its records (so OSC 7501 keeps deciding presence) with done/error
    /// turned to idle.
    public mutating func markFinishedSeen() {
        for (id, record) in records where record.state == .done || record.state == .error {
            records[id]?.state = .idle
        }
    }

    /// Drop `done` and `error` records once the user has looked at the pane.
    public mutating func acknowledgeFinished() {
        remove { _, record in record.state == .done || record.state == .error }
    }

    public mutating func removeAll() {
        records.removeAll()
        updateOrder.removeAll()
    }

    /// The record that should drive the pane's indicator: the most urgent,
    /// preferring the root record on ties, then the most recently updated.
    public var primary: ProgramStatusReport? {
        updateOrder.reversed()
            .compactMap { records[$0] }
            .max { lhs, rhs in
                if lhs.state.urgency != rhs.state.urgency { return lhs.state.urgency < rhs.state.urgency }
                return !lhs.id.isEmpty && rhs.id.isEmpty
            }
    }

    /// Live activity implied by the records, or nil when there are none.
    /// Blocked anywhere wins; then working anywhere (root's progress
    /// preferred); otherwise the program is at rest (idle, done or error).
    public var activity: PaneActivity? {
        guard let primary else { return nil }
        if primary.state == .blocked { return .blocked(primary.kind) }
        let working = updateOrder.reversed().compactMap { records[$0] }.filter { $0.state == .working }
        if let record = working.first(where: { $0.id.isEmpty }) ?? working.first {
            return .working(progress: record.progress)
        }
        return .idle
    }

    /// `app` for a record, inherited from its nearest ancestor when absent.
    public func effectiveApp(for id: String) -> String? {
        var path = id
        while true {
            if let app = records[path]?.app { return app }
            if path.isEmpty { return nil }
            path = path.range(of: "/", options: .backwards).map { String(path[..<$0.lowerBound]) } ?? ""
        }
    }

    private mutating func remove(where shouldRemove: (String, ProgramStatusReport) -> Bool) {
        let doomed = Set(records.filter { shouldRemove($0.key, $0.value) }.keys)
        guard !doomed.isEmpty else { return }
        for id in doomed {
            records.removeValue(forKey: id)
        }
        updateOrder.removeAll { doomed.contains($0) }
    }
}
