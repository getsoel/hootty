import Foundation

/// Filter categories for the sidebar badge pills.
/// Each case corresponds to a pane state that the sidebar badges track.
public enum SidebarFilter: String, CaseIterable, Sendable {
    case thinking
    case flagged
    case done
    case bell
}
