import Foundation

/// A named, isolated set of workspaces and configuration.
public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// Top-level metadata persisted to `profiles.json`.
public struct ProfilesMetadata: Codable, Equatable {
    public var activeProfileID: UUID
    public var profiles: [Profile]

    public init(activeProfileID: UUID, profiles: [Profile]) {
        self.activeProfileID = activeProfileID
        self.profiles = profiles
    }
}
