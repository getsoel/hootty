---
globs: Sources/HoottyCore/AppCommand.swift, Sources/Hootty/CommandRegistry.swift, Sources/Hootty/HoottyApp.swift, Sources/Hootty/Views/CommandPaletteView.swift
---

The command system has three layers. Full reference: `docs/COMMANDS.md`.

**AppCommand** (HoottyCore) — enum of all commands with `title` and `shortcutHint`. UI-free, testable.

**CommandRegistry** (Hootty) — `@Observable` class mapping `AppCommand` → closures. `execute(_:)` dispatches. `paletteCommands` auto-generates palette entries. `setSupplementaryCommands(_:)` for dynamic entries (themes).

**Dispatch points** — SwiftUI `.commands` menus, CommandPaletteView, and GhosttyApp action callbacks all call `commandRegistry.execute()`.

To add a new command:
1. Add case to `AppCommand` enum with `title` and optional `shortcutHint`
2. Register handler in `HoottyApp.registerCommands()`
3. Optionally add a menu item in `.commands` block (use `AppCommand.foo.title` for label, `.keyboardShortcut()` for menu display)
4. Optionally handle the ghostty action in `GhosttyApp.handleAction`
5. It automatically appears in the command palette

Menu `.keyboardShortcut()` modifiers must stay on menu buttons — SwiftUI requires them for menu bar shortcut display. The `shortcutHint` on `AppCommand` is display-only (for the palette).

Ghostty actions route through `GhosttyApp.shared.commandRegistry?.execute()` on the main queue. The `commandRegistry` is a `weak` reference set by HoottyApp during init.
