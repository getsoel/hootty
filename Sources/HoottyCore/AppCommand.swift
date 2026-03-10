import Foundation

/// Canonical list of all app-level commands.
/// Single source of truth for command identity, display names, and shortcut hints.
/// Lives in HoottyCore (UI-free) so it's testable. Action closures are wired
/// in the UI layer via CommandRegistry.
public enum AppCommand: String, CaseIterable, Identifiable, Sendable {
    // Workspace
    case newWorkspace
    case closeWorkspace

    // Splits
    case splitRight
    case splitDown
    case splitLeft
    case splitUp

    // Navigation
    case nextWorkspace
    case previousWorkspace
    case focusNextPane
    case focusPreviousPane

    // View
    case toggleSidebar
    case toggleCommandPalette
    case changeTheme

    // App
    case editConfig

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newWorkspace: return "New Workspace"
        case .closeWorkspace: return "Close Workspace"
        case .splitRight: return "Split Right"
        case .splitDown: return "Split Down"
        case .splitLeft: return "Split Left"
        case .splitUp: return "Split Up"
        case .nextWorkspace: return "Next Workspace"
        case .previousWorkspace: return "Previous Workspace"
        case .focusNextPane: return "Focus Next Pane"
        case .focusPreviousPane: return "Focus Previous Pane"
        case .toggleSidebar: return "Toggle Sidebar"
        case .toggleCommandPalette: return "Command Palette"
        case .changeTheme: return "Change Theme..."
        case .editConfig: return "Edit Configuration..."
        }
    }

    /// Display-only shortcut string for the command palette.
    /// nil means this command has no default keyboard shortcut in Hootty menus.
    /// (Ghostty may still bind it via its own keybinding system.)
    public var shortcutHint: String? {
        switch self {
        case .newWorkspace: return "⌘T"
        case .splitRight: return "⌘D"
        case .splitDown: return "⇧⌘D"
        case .splitLeft: return "⌥⌘D"
        case .splitUp: return "⌥⇧⌘D"
        case .toggleSidebar: return "⇧⌘S"
        case .toggleCommandPalette: return "⇧⌘P"
        case .editConfig: return "⌘,"
        case .nextWorkspace: return "⌃⇥"
        case .previousWorkspace: return "⌃⇧⇥"
        default: return nil
        }
    }
}
