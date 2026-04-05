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
    case focusPaneUp
    case focusPaneDown
    case focusPaneLeft
    case focusPaneRight

    /// Splits (actions)
    case equalizeSplits

    /// Toggle note on focused pane
    case notePane

    /// Toggle flag on focused pane
    case flagPane

    // View
    case toggleSidebar
    case focusSidebar
    case toggleCommandPalette
    case changeTheme
    case refreshTerminal

    /// Branches
    case refreshBranches

    // App
    case attentionSounds
    case resetWorkspaces
    case editConfig

    // Workspace collapse
    case collapseAllWorkspaces
    case expandAllWorkspaces

    case clearSidebarFilters

    // Persistent panel
    case togglePersistentPanel
    case focusPersistentPanel
    case movePaneToPersistentPanel
    case movePaneToWorkspace
    case movePanelLeft
    case movePanelRight
    case movePanelTop
    case movePanelBottom

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .newWorkspace: "New Workspace"
        case .closeWorkspace: "Close Workspace"
        case .splitRight: "Split Right"
        case .splitDown: "Split Down"
        case .splitLeft: "Split Left"
        case .splitUp: "Split Up"
        case .nextWorkspace: "Next Workspace"
        case .previousWorkspace: "Previous Workspace"
        case .focusNextPane: "Focus Next Pane"
        case .focusPreviousPane: "Focus Previous Pane"
        case .focusPaneUp: "Focus Pane Up"
        case .focusPaneDown: "Focus Pane Down"
        case .focusPaneLeft: "Focus Pane Left"
        case .focusPaneRight: "Focus Pane Right"
        case .equalizeSplits: "Equalize Splits"
        case .notePane: "Note Pane"
        case .flagPane: "Flag Pane"
        case .toggleSidebar: "Toggle Sidebar"
        case .focusSidebar: "Focus Sidebar"
        case .toggleCommandPalette: "Command Palette"
        case .changeTheme: "Change Theme..."
        case .refreshTerminal: "Refresh Terminal"
        case .refreshBranches: "Refresh Branches"
        case .attentionSounds: "Attention Sounds..."
        case .resetWorkspaces: "Reset Workspaces"
        case .editConfig: "Edit Configuration..."
        case .collapseAllWorkspaces: "Collapse All Workspaces"
        case .expandAllWorkspaces: "Expand All Workspaces"
        case .clearSidebarFilters: "Clear Sidebar Filters"
        case .togglePersistentPanel: "Toggle Persistent Panel"
        case .focusPersistentPanel: "Focus Persistent Panel"
        case .movePaneToPersistentPanel: "Move Pane to Pinned"
        case .movePaneToWorkspace: "Move Pane to Workspace"
        case .movePanelLeft: "Move Panel Left"
        case .movePanelRight: "Move Panel Right"
        case .movePanelTop: "Move Panel Top"
        case .movePanelBottom: "Move Panel Bottom"
        }
    }

    /// Display-only shortcut string for the command palette.
    /// nil means this command has no default keyboard shortcut in Hootty menus.
    /// (Ghostty may still bind it via its own keybinding system.)
    public var shortcutHint: String? {
        switch self {
        case .newWorkspace: "⌘T"
        case .splitRight: "⌘D"
        case .splitDown: "⇧⌘D"
        case .splitLeft: "⌥⌘D"
        case .splitUp: "⌥⇧⌘D"
        case .toggleSidebar: "⇧⌘S"
        case .focusSidebar: "⌘0"
        case .toggleCommandPalette: "⇧⌘P"
        case .editConfig: "⌘,"
        case .nextWorkspace: "⌃⇥"
        case .previousWorkspace: "⌃⇧⇥"
        case .focusPaneUp: "⌥⌘↑"
        case .focusPaneDown: "⌥⌘↓"
        case .focusPaneLeft: "⌥⌘←"
        case .focusPaneRight: "⌥⌘→"
        case .equalizeSplits: "⌃⇧="
        case .notePane: "⌃⇧F"
        case .flagPane: "⌃⇧G"
        case .togglePersistentPanel: "⌘⌥P"
        case .focusPersistentPanel: "⌘\\"
        default: nil
        }
    }
}
