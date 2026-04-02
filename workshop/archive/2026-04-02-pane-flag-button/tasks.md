# Tasks: Pane Flag Button

## 1. Model — Pane Flag Property

- [x] 1.1 Add `public var isFlagged: Bool = false` to `Pane` in `Sources/HoottyCore/Pane.swift`
- [x] 1.2 Add `public func toggleFlag()` method that flips `isFlagged`
- [x] 1.3 Verify `isFlagged` is excluded from `CodingKeys` (not persisted)
- [x] 1.4 Add unit test in `Tests/HoottyCoreTests/` verifying `toggleFlag()` flips state and flag is independent of note

## 2. Command — AppCommand + Registry

- [x] 2.1 Add `case flagPane` to `AppCommand` in `Sources/HoottyCore/AppCommand.swift`
- [x] 2.2 Add title `"Flag Pane"` in the `title` switch
- [x] 2.3 Add `shortcutHint` `"⌃⇧G"` in the `shortcutHint` switch
- [x] 2.4 Register `flagPane` handler in `HoottyApp.registerCommands()` — toggle focused pane's flag via `pane.toggleFlag()`

## 3. Pane Bar — Flag Button

- [x] 3.1 Add `onToggleFlag: (() -> Void)?` callback to `PaneBar` in `Sources/Hootty/Views/PaneGroupTabBar.swift`
- [x] 3.2 Add `BarIconButton` for flag toggle after the note button, using `"flag"` / `"flag.fill"` and conditional `statusWarning` color
- [x] 3.3 Wire `onToggleFlag` from the parent view that creates `PaneBar`

## 4. Sidebar — Flag Indicator

- [x] 4.1 Add flag icon (`"flag.fill"` with `statusWarning` color) to `SidebarPaneRow` in `Sources/Hootty/Views/SidebarPaneRow.swift`, shown when `pane.isFlagged`
- [x] 4.2 Add yellow-tinted background (`statusWarning.withAlphaComponent(0.15)`) to the sidebar row when flagged

## 5. Keyboard Shortcut + Menu

- [x] 5.1 Add menu item for "Flag Pane" with `Ctrl+Shift+G` keyboard shortcut in the SwiftUI `.commands` block
- [x] 5.2 Verify shortcut does not conflict with existing bindings

## 6. Verification

- [x] 6.1 Run `swift test` — all tests pass
- [x] 6.2 Run `make build` — compiles without errors
- [x] 6.3 Run `make format-check` — formatting passes
- [x] 6.4 Run `make lint` — no lint warnings
