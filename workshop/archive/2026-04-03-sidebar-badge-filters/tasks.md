# Tasks: Sidebar Badge Filters

## 1. Filter Model (HoottyCore)

- [x] 1.1 Create `Sources/HoottyCore/SidebarFilter.swift` with `SidebarFilter` enum (cases: `.thinking`, `.flagged`, `.done`, `.bell`)
- [x] 1.2 Add `activeSidebarFilters: Set<SidebarFilter>` to `AppModel`, plus `toggleSidebarFilter(_:)`, `clearSidebarFilters()`, and computed `isFilteringSidebar`
- [x] 1.3 Add `func matches(_ filters: Set<SidebarFilter>) -> Bool` to `Pane` with OR logic
- [x] 1.4 Add unit tests for `Pane.matches(_:)` — empty filters returns true, single filter matches correct property, multiple filters use OR logic, non-matching returns false

## 2. Keyboard Navigation Filter Support

- [x] 2.1 Add `activeFilters: Set<SidebarFilter> = []` parameter to `SidebarKeyboardNav.allNavigableItems()` — filter out panes that don't match and aren't the focused pane of the selected workspace
- [x] 2.2 Pass `selectedWorkspaceID` context into the pane filtering logic so only the selected workspace's focused pane is pinned
- [x] 2.3 Add tests for `allNavigableItems` with filters: panes not matching filter are excluded, focused pane of selected workspace is always included, workspace rows are always included, empty filters returns all items

## 3. Command Integration

- [x] 3.1 Add `clearSidebarFilters` case to `AppCommand` with title "Clear Sidebar Filters" and no shortcut hint
- [x] 3.2 Register `clearSidebarFilters` handler in `HoottyApp.registerCommands()` calling `appModel.clearSidebarFilters()`

## 4. Sidebar Pane List Filtering

- [x] 4.1 Thread `activeSidebarFilters` from `AppModel` through `ContentView` into `WorkspaceSidebar` (add as a binding or let parameter)
- [x] 4.2 In `workspacePaneList()`, filter `section.panes` to only include panes matching active filters OR the focused pane of the selected workspace
- [x] 4.3 Hide branch section headers (`BranchSectionHeader`) when their filtered pane list is empty
- [x] 4.4 Update `scrollTargetIDs` to exclude filtered-out panes (keep workspace IDs and pinned focused pane)

## 5. Badge Pill Interaction

- [x] 5.1 Add tap gesture to each badge pill (thinking, flagged, done, bell) calling `appModel.toggleSidebarFilter(_:)` for the corresponding filter
- [x] 5.2 Add `.contentShape(Capsule())` before tap gesture on each pill
- [x] 5.3 Add pointing hand cursor on hover for each pill via `.onContinuousHover` with `DispatchQueue.main.async { NSCursor.pointingHand.set() }`

## 6. Badge Pill Visual States

- [x] 6.1 Refactor `thinkingPill` and `attentionPill` to accept an `isFilterActive: Bool` parameter
- [x] 6.2 When filter is active: use category color for text/icon (regardless of count), 0.3 opacity fill, 1pt capsule border at 0.6 opacity of category color
- [x] 6.3 When filter is inactive: keep existing behavior (muted at count 0, colored at count > 0, 0.15 fill, no border)

## 7. Escape Key Two-Step

- [x] 7.1 Modify Escape key handler in `WorkspaceSidebar`: if `isFilteringSidebar`, call `clearSidebarFilters()` and return `.handled` without defocusing; else defocus sidebar (existing behavior)

## 8. Verify & Build

- [x] 8.1 `swift test` passes (filter matching tests, keyboard nav filter tests)
- [x] 8.2 `make build` succeeds
- [x] 8.3 `make format-check` passes
- [x] 8.4 `make lint` passes
