# Command System

Hootty uses a centralized command registry for keyboard shortcuts and the command palette.

## Architecture

```
HoottyCore/AppCommand.swift     ← Command enum (ID, title, shortcut hint)
Hootty/CommandRegistry.swift    ← Maps commands → actions, generates palette entries
Hootty/HoottyApp.swift          ← Registers handlers, wires to menus + ghostty
```

### Layers

1. **`AppCommand`** (HoottyCore) — A `CaseIterable` enum defining every app-level command. Each case has a `title` (display name) and optional `shortcutHint` (display-only string like `"⌘D"`). Lives in HoottyCore so it's testable with no UI dependencies.

2. **`CommandRegistry`** (Hootty) — An `@Observable` class that maps `AppCommand` → action closures. Provides:
   - `register(_:handler:)` — bind an action to a command
   - `execute(_:)` — dispatch a command (used by menus, ghostty callbacks, and palette)
   - `paletteCommands` — auto-generates `PaletteCommand` entries for the command palette
   - `setSupplementaryCommands(_:)` — for dynamic entries (e.g. theme selection) that don't have static `AppCommand` cases

3. **SwiftUI `.commands`** (HoottyApp) — Menu bar items call `commandRegistry.execute(.foo)`. The `.keyboardShortcut()` modifiers remain on each `Button` because SwiftUI requires them to display shortcuts in the menu bar.

4. **Ghostty action callbacks** (GhosttyApp) — Actions like `GHOSTTY_ACTION_TOGGLE_COMMAND_PALETTE`, `GHOSTTY_ACTION_GOTO_TAB`, and `GHOSTTY_ACTION_GOTO_SPLIT` route through `commandRegistry.execute()`.

### Data flow

```
User presses shortcut
    ↓
SwiftUI menu system OR ghostty keybinding system intercepts
    ↓
commandRegistry.execute(.someCommand)
    ↓
Registered closure runs (modifies AppModel, GhosttyApp, etc.)
    ↓
SwiftUI reacts to @Observable changes

User opens command palette
    ↓
commandRegistry.paletteCommands → [PaletteCommand]
    ↓
CommandPaletteView displays list with titles + shortcut hints
    ↓
User selects → commandRegistry.execute(.someCommand)
```

## Adding a New Command

1. **Add the case** to `AppCommand` in `Sources/HoottyCore/AppCommand.swift`:
   ```swift
   case myNewCommand
   ```

2. **Add `title`** in the switch:
   ```swift
   case .myNewCommand: return "My New Command"
   ```

3. **Add `shortcutHint`** (optional) if it has a keyboard shortcut:
   ```swift
   case .myNewCommand: return "⌘N"
   ```

4. **Register the handler** in `HoottyApp.registerCommands()`:
   ```swift
   commandRegistry.register(.myNewCommand) { [appModel] in
       // action here
   }
   ```

5. **Add a menu item** (optional) in the `.commands` block:
   ```swift
   Button(AppCommand.myNewCommand.title) {
       commandRegistry.execute(.myNewCommand)
   }
   .keyboardShortcut("n", modifiers: .command)
   ```

6. **Add a ghostty action handler** (optional) if ghostty can trigger it:
   ```swift
   case GHOSTTY_ACTION_MY_ACTION:
       DispatchQueue.main.async {
           GhosttyApp.shared.commandRegistry?.execute(.myNewCommand)
       }
       return true
   ```

The command automatically appears in the command palette with its title and shortcut hint — no additional wiring needed.

## Available Commands

| Command | Title | Shortcut | Source |
|---------|-------|----------|--------|
| `newWorkspace` | New Workspace | ⌘T | Menu + Ghostty |
| `closeWorkspace` | Close Workspace | — | Palette |
| `splitRight` | Split Right | ⌘D | Menu + Ghostty |
| `splitDown` | Split Down | ⇧⌘D | Menu + Ghostty |
| `splitLeft` | Split Left | ⌥⌘D | Menu |
| `splitUp` | Split Up | ⌥⇧⌘D | Menu |
| `nextWorkspace` | Next Workspace | ⌃⇥ | Ghostty |
| `previousWorkspace` | Previous Workspace | ⌃⇧⇥ | Ghostty |
| `focusNextPane` | Focus Next Pane | — | Ghostty |
| `focusPreviousPane` | Focus Previous Pane | — | Ghostty |
| `toggleSidebar` | Toggle Sidebar | ⇧⌘S | Menu |
| `toggleCommandPalette` | Command Palette | ⇧⌘P | Menu + Ghostty |
| `changeTheme` | Change Theme... | — | Menu + Palette |
| `editConfig` | Edit Configuration... | ⌘, | Menu |

**Source** indicates where the shortcut can be triggered from:
- **Menu** — SwiftUI `.commands` menu bar (always available)
- **Ghostty** — ghostty keybinding system (when terminal has focus)
- **Palette** — command palette only (all commands appear here)

## Supplementary Commands

Dynamic commands that don't map to a static `AppCommand` case use `commandRegistry.setSupplementaryCommands()`. These appear in the palette but aren't part of the enum. Theme selection previously used supplementary commands but now uses a dedicated theme picker overlay opened via the `changeTheme` command.

## Design Decisions

- **No user-configurable keybindings at the Hootty level.** Ghostty already has a keybinding system via its config file. Adding another would create confusion about which system takes precedence.
- **No `KeyboardShortcut` in HoottyCore.** Keeps the core target free of SwiftUI dependencies and testable.
- **`shortcutHint` is display-only.** The actual shortcut binding lives in `.keyboardShortcut()` modifiers on menu items. The hint is only used for the command palette display.
- **Ghostty actions route through the registry** so that all command dispatch goes through a single path, making it easier to add logging, analytics, or undo in the future.
