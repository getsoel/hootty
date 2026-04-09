import Foundation

/// Detected activity state of an agent CLI running inside a terminal pane.
public enum AgentPresence: Equatable, Sendable {
    /// Agent is processing (animated thinking indicator).
    case thinking
    /// Agent is waiting with no outstanding attention request.
    case idle
    /// Agent has explicitly flagged that user input is required.
    case needsAttention
}
