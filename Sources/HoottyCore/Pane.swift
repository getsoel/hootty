import Foundation

public enum AttentionKind: String, Codable, Sendable {
    /// Claude finished and is waiting for the next prompt.
    case idle
    /// Claude needs user input (permission approval, question, etc.)
    case input
    /// Bell rang on the focused pane (visual-only, cleared by next user interaction).
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

    public var displayName: String {
        customName ?? name
    }

    public init(id: UUID = UUID(), name: String, customName: String? = nil, shell: String = "/bin/zsh", workingDirectory: String? = nil, claudeSessionID: String? = nil) {
        self.id = id
        self.name = name
        self.customName = customName
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.claudeSessionID = claudeSessionID
    }
}

extension Pane: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, customName, shell, workingDirectory, claudeSessionID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            customName: try container.decodeIfPresent(String.self, forKey: .customName),
            shell: try container.decode(String.self, forKey: .shell),
            workingDirectory: try container.decode(String.self, forKey: .workingDirectory),
            claudeSessionID: try container.decodeIfPresent(String.self, forKey: .claudeSessionID)
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
    }
}
