import Foundation

public enum AttentionKind: String, Codable, Sendable {
    /// Bell rang (visual-only, cleared by next user interaction).
    case bell
    /// Claude finished thinking, needs input (cleared by next user interaction).
    case done
    /// Manually flagged by user (cleared by next user interaction).
    case flag
}

@MainActor
@Observable
public final class Pane: Identifiable {
    public let id: UUID
    public var name: String
    public var customName: String?
    public var isRunning = true
    public var attentionKind: AttentionKind?
    public var flagNote: String?
    public var isThinking = false

    public var needsAttention: Bool {
        attentionKind != nil
    }

    /// Whether the pane has a manual flag that automated events should not override.
    public var isFlagged: Bool {
        attentionKind == .flag
    }

    public func setFlag(note: String? = nil) {
        attentionKind = .flag
        flagNote = note
    }

    public func clearFlag() {
        attentionKind = nil
        flagNote = nil
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

    public init(id: UUID = UUID(), name: String, customName: String? = nil, shell: String = "/bin/zsh", workingDirectory: String? = nil, claudeSessionID: String? = nil, branch: String? = nil, repoRoot: String? = nil, worktreePath: String? = nil) {
        self.id = id
        self.name = name
        self.customName = customName
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.claudeSessionID = claudeSessionID
        self.branch = branch
        self.repoRoot = repoRoot
        self.worktreePath = worktreePath
    }
}

extension Pane: @preconcurrency Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, customName, shell, workingDirectory, claudeSessionID, branch, repoRoot, worktreePath
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
            worktreePath: container.decodeIfPresent(String.self, forKey: .worktreePath)
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
    }
}
