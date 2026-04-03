import Foundation

public enum AttentionKind: String, CaseIterable, Codable, Sendable {
    /// Bell rang (visual-only, cleared by next user interaction).
    case bell
    /// Claude finished thinking, needs input (cleared by next user interaction).
    case done

    public var displayName: String {
        switch self {
        case .bell: "Bell"
        case .done: "Claude Done"
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
    public var claudeSessionID: String?
    public var branch: String?
    public var repoRoot: String?
    public var worktreePath: String?

    public var displayName: String {
        if let customName { return customName }
        if claudeSessionID != nil { return name }
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

    public init(id: UUID = UUID(), name: String, customName: String? = nil, shell: String = "/bin/zsh", workingDirectory: String? = nil, claudeSessionID: String? = nil, branch: String? = nil, repoRoot: String? = nil, worktreePath: String? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.customName = customName
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.claudeSessionID = claudeSessionID
        self.branch = branch
        self.repoRoot = repoRoot
        self.worktreePath = worktreePath
        self.note = note
    }
}

extension Pane: @preconcurrency Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, customName, shell, workingDirectory, claudeSessionID, branch, repoRoot, worktreePath, note
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            name: container.decode(String.self, forKey: .name),
            customName: container.decodeIfPresent(String.self, forKey: .customName),
            shell: container.decode(String.self, forKey: .shell),
            workingDirectory: container.decode(String.self, forKey: .workingDirectory),
            claudeSessionID: container.decodeIfPresent(String.self, forKey: .claudeSessionID),
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
        try container.encodeIfPresent(claudeSessionID, forKey: .claudeSessionID)
        try container.encodeIfPresent(branch, forKey: .branch)
        try container.encodeIfPresent(repoRoot, forKey: .repoRoot)
        try container.encodeIfPresent(worktreePath, forKey: .worktreePath)
        try container.encodeIfPresent(note, forKey: .note)
    }
}
