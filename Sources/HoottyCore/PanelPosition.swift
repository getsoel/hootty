import Foundation

/// Position of the persistent panel relative to the workspace detail area.
public enum PanelPosition: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom

    /// Whether this position uses horizontal (width) or vertical (height) sizing.
    public var isHorizontal: Bool {
        self == .left || self == .right
    }
}
