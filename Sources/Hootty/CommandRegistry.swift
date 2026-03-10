import SwiftUI
import HoottyCore

/// Maps AppCommand to executable actions. Single dispatch point for menus,
/// command palette, and ghostty action callbacks.
@Observable
final class CommandRegistry {
    private var handlers: [AppCommand: () -> Void] = [:]

    /// Additional palette-only commands (e.g. theme selection) that don't have
    /// a static AppCommand entry.
    private var supplementaryCommands: [PaletteCommand] = []

    func register(_ command: AppCommand, handler: @escaping () -> Void) {
        handlers[command] = handler
    }

    func execute(_ command: AppCommand) {
        handlers[command]?()
    }

    func setSupplementaryCommands(_ commands: [PaletteCommand]) {
        supplementaryCommands = commands
    }

    /// All commands for the command palette: registered AppCommands + supplementary.
    var paletteCommands: [PaletteCommand] {
        let appCommands: [PaletteCommand] = AppCommand.allCases.compactMap { cmd in
            guard handlers[cmd] != nil else { return nil }
            return PaletteCommand(
                id: cmd.rawValue,
                title: cmd.title,
                shortcut: cmd.shortcutHint,
                action: { [weak self] in self?.execute(cmd) }
            )
        }
        return appCommands + supplementaryCommands
    }
}
