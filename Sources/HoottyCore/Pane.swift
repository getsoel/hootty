import Foundation

@Observable
public final class Pane: Identifiable {
    public let id: UUID
    public var name: String
    public var isRunning = true
    public var needsAttention = false
    public var shell: String
    public var workingDirectory: String

    public init(id: UUID = UUID(), name: String, shell: String = "/bin/zsh", workingDirectory: String? = nil) {
        self.id = id
        self.name = name
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
    }
}

extension Pane: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, shell, workingDirectory
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            shell: try container.decode(String.self, forKey: .shell),
            workingDirectory: try container.decode(String.self, forKey: .workingDirectory)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(shell, forKey: .shell)
        try container.encode(workingDirectory, forKey: .workingDirectory)
    }
}
