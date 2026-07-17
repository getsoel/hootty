import Foundation

/// A durable record of a resumable agent session captured from a live pane.
///
/// Distinct from `Pane.agentSessionID` (a transient live-presence marker): this
/// is a passive "this pane last hosted this recoverable Claude session" record
/// that survives app restart so the conversation can be brought back via
/// `claude --resume <sessionID>`. `configDir` carries the session's
/// `CLAUDE_CONFIG_DIR` (when non-default) so config-dir-scoped sessions resolve.
public struct ResumableSession: Codable, Equatable, Sendable {
    public var sessionID: String
    public var configDir: String?

    public init(sessionID: String, configDir: String? = nil) {
        self.sessionID = sessionID
        self.configDir = configDir
    }

    /// The shell command that resumes this session, ready to type into a pane.
    ///
    /// Prefixes `CLAUDE_CONFIG_DIR=<dir>` when the session used a non-default
    /// config dir, so config-dir-scoped sessions (e.g. `claude-soel`) resolve —
    /// a bare `--resume` looks only in the default config dir and would fail.
    /// `dangerouslySkipPermissions` defaults on to match how these sessions are
    /// typically started (all the `claude-*` aliases pass the flag). `claude`
    /// resolves to Hootty's PATH wrapper, which re-injects the tracking hooks.
    public func resumeCommand(dangerouslySkipPermissions: Bool = true) -> String {
        var command = ""
        if let configDir, !configDir.isEmpty {
            command += "CLAUDE_CONFIG_DIR=\(Self.singleQuoted(configDir)) "
        }
        command += "claude"
        if dangerouslySkipPermissions {
            command += " --dangerously-skip-permissions"
        }
        // sessionID is validated as a UUID at capture — no shell metacharacters.
        command += " --resume \(sessionID)"
        return command
    }

    /// POSIX single-quote a value so paths with spaces or metacharacters survive
    /// intact. Embedded single quotes are closed, escaped, and reopened.
    private static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum AttentionKind: String, CaseIterable, Codable, Sendable {
    /// Bell rang (visual-only, cleared by next user interaction).
    case bell
    /// Agent finished thinking, needs input (cleared by next user interaction).
    case done
    /// Agent encountered an error (cleared by next user interaction).
    case error

    public var displayName: String {
        switch self {
        case .bell: "Bell"
        case .done: "Agent Done"
        case .error: "Error"
        }
    }
}

@MainActor
@Observable
public final class Pane: Identifiable {
    public let id: UUID
    public var name: String
    public var customName: String?
    public var isRunning = true
    public var attentionKind: AttentionKind?
    public var note: String?
    public var isFlagged = false
    public var isThinking = false

    public var needsAttention: Bool {
        attentionKind != nil
    }

    /// Whether the pane has a note attached.
    public var hasNote: Bool {
        note != nil
    }

    public func setNote(_ text: String?) {
        note = text?.isEmpty == true ? nil : text
    }

    public func toggleFlag() {
        isFlagged.toggle()
    }

    /// Returns true if this pane matches any of the given sidebar filters (OR logic).
    /// An empty filter set matches all panes.
    public func matches(_ filters: Set<SidebarFilter>) -> Bool {
        if filters.isEmpty { return true }
        for filter in filters {
            switch filter {
            case .thinking: if isThinking { return true }
            case .flagged: if isFlagged { return true }
            case .done: if attentionKind == .done { return true }
            case .bell: if attentionKind == .bell { return true }
            case .error: if attentionKind == .error { return true }
            }
        }
        return false
    }

    /// Whether this pane should be visible in a filtered sidebar.
    /// The focused pane of the selected workspace is always pinned visible.
    public func isVisibleInSidebar(isFocusedInSelectedWorkspace: Bool, filters: Set<SidebarFilter>) -> Bool {
        isFocusedInSelectedWorkspace || matches(filters)
    }

    public var shell: String
    public var workingDirectory: String
    /// Sentinel value written to `agentSessionID` when an agent session is
    /// inferred from title detection rather than an explicit hook-injected ID.
    public static let autoSessionID = "auto"

    public var agentSessionID: String?
    /// Human-readable agent name set by the hootty:agent: protocol message.
    public var agentName: String?
    /// A recoverable agent session captured while the pane was live. Persisted
    /// and preserved across restart so the conversation can be resumed after a
    /// crash. Kept separate from `agentSessionID` so a restored pane (running a
    /// plain shell) does not paint a false "agent running" indicator.
    public var resumable: ResumableSession?
    public var branch: String?
    public var repoRoot: String?
    public var worktreePath: String?

    public var displayName: String {
        if let customName { return customName }
        if agentSessionID != nil { return name }
        return Self.abbreviatePath(workingDirectory)
    }

    /// Abbreviate an absolute path by replacing the home directory prefix with ~.
    private static func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    /// Repository name derived from repoRoot, worktree, or working directory path.
    public var repoName: String? {
        guard branch != nil else { return nil }
        if let repoRoot { return URL(fileURLWithPath: repoRoot).lastPathComponent }
        let path = worktreePath ?? workingDirectory
        return URL(fileURLWithPath: path).lastPathComponent
    }

    public init(id: UUID = UUID(), name: String, customName: String? = nil, shell: String = "/bin/zsh", workingDirectory: String? = nil, agentSessionID: String? = nil, agentName: String? = nil, resumable: ResumableSession? = nil, branch: String? = nil, repoRoot: String? = nil, worktreePath: String? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.customName = customName
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.agentSessionID = agentSessionID
        self.agentName = agentName
        self.resumable = resumable
        self.branch = branch
        self.repoRoot = repoRoot
        self.worktreePath = worktreePath
        self.note = note
    }
}

extension Pane: @preconcurrency Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, customName, shell, workingDirectory, agentSessionID, agentName, resumable, branch, repoRoot, worktreePath, note
        /// Legacy key from pre-multi-agent builds. Decoded as a fallback for
        /// `agentSessionID`; never encoded.
        case claudeSessionID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawAgentSession = try container.decodeIfPresent(String.self, forKey: .agentSessionID)
            ?? container.decodeIfPresent(String.self, forKey: .claudeSessionID)
        // Discard the `autoSessionID` sentinel on restore — it's a runtime
        // detection marker with no meaning without a live process. A fresh
        // surface will re-detect via title watching if an agent is running.
        let agentSession = rawAgentSession == Self.autoSessionID ? nil : rawAgentSession
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            name: container.decode(String.self, forKey: .name),
            customName: container.decodeIfPresent(String.self, forKey: .customName),
            shell: container.decode(String.self, forKey: .shell),
            workingDirectory: container.decode(String.self, forKey: .workingDirectory),
            agentSessionID: agentSession,
            agentName: container.decodeIfPresent(String.self, forKey: .agentName),
            resumable: container.decodeIfPresent(ResumableSession.self, forKey: .resumable),
            branch: container.decodeIfPresent(String.self, forKey: .branch),
            repoRoot: container.decodeIfPresent(String.self, forKey: .repoRoot),
            worktreePath: container.decodeIfPresent(String.self, forKey: .worktreePath),
            note: container.decodeIfPresent(String.self, forKey: .note)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encode(shell, forKey: .shell)
        try container.encode(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(agentSessionID, forKey: .agentSessionID)
        try container.encodeIfPresent(agentName, forKey: .agentName)
        try container.encodeIfPresent(resumable, forKey: .resumable)
        try container.encodeIfPresent(branch, forKey: .branch)
        try container.encodeIfPresent(repoRoot, forKey: .repoRoot)
        try container.encodeIfPresent(worktreePath, forKey: .worktreePath)
        try container.encodeIfPresent(note, forKey: .note)
    }
}
