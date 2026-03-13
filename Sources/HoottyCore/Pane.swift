import Foundation

public enum AttentionKind: String, Codable, Sendable {
    /// Bell rang (visual-only, cleared by next user interaction).
    case bell
}

@Observable
public final class Pane: Identifiable {
    public let id: UUID
    public var name: String
    public var customName: String?
    public var isRunning = true
    public var attentionKind: AttentionKind?
    public var isThinking = false

    public var needsAttention: Bool { attentionKind != nil }
    public var shell: String
    public var workingDirectory: String
    public var claudeSessionID: String?
    public var branch: String?
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

    /// Repository name derived from worktree or working directory path.
    public var repoName: String? {
        guard branch != nil else { return nil }
        let path = worktreePath ?? workingDirectory
        return URL(fileURLWithPath: path).lastPathComponent
    }

    public init(id: UUID = UUID(), name: String, customName: String? = nil, shell: String = "/bin/zsh", workingDirectory: String? = nil, claudeSessionID: String? = nil, branch: String? = nil, worktreePath: String? = nil) {
        self.id = id
        self.name = name
        self.customName = customName
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.claudeSessionID = claudeSessionID
        self.branch = branch
        self.worktreePath = worktreePath
    }
}

extension Pane: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, customName, shell, workingDirectory, claudeSessionID, branch, worktreePath
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            customName: try container.decodeIfPresent(String.self, forKey: .customName),
            shell: try container.decode(String.self, forKey: .shell),
            workingDirectory: try container.decode(String.self, forKey: .workingDirectory),
            claudeSessionID: try container.decodeIfPresent(String.self, forKey: .claudeSessionID),
            branch: try container.decodeIfPresent(String.self, forKey: .branch),
            worktreePath: try container.decodeIfPresent(String.self, forKey: .worktreePath)
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
        try container.encodeIfPresent(worktreePath, forKey: .worktreePath)
    }
}
