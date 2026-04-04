import Foundation

/// Tracks which focus domain currently has application focus.
public enum FocusDomain: String, Codable, Sendable {
    /// Focus is in the selected workspace's split tree.
    case workspace
    /// Focus is in the persistent panel's split tree.
    case persistent
}
