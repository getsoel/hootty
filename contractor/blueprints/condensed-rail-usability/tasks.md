## 1. Remove Broken Tooltip Infrastructure

- [ ] 1.1 Delete the `RailTooltipModifier` struct (around `CondensedSidebar.swift:518-545`).
- [ ] 1.2 Delete the `private extension View { func railTooltip(...) }` helper directly below it.
- [ ] 1.3 Remove every existing `.railTooltip(...)` call site (`CondensedRowView`, `WorkspaceRailRow`, `PaneRailRow`). The file will temporarily have no tooltip coverage; that is fine — tasks in group 3 replace them.

## 2. Fix Click-to-Collapse on Workspace Rail Row

- [ ] 2.1 Add an `onToggleCollapse: () -> Void` parameter to the private `WorkspaceRailRow` struct in `CondensedSidebar.swift`.
- [ ] 2.2 Change `WorkspaceRailRow.onTapGesture` to call `onToggleCollapse()` (wrapped in `withAnimation(.easeInOut(duration: 0.15))`) and remove the existing `onSelect()` invocation from the tap handler. Keep the `onSelect` parameter off the row entirely or delete it if it has no other callers.
- [ ] 2.3 Update the `workspaceRow(workspace:isActive:isCollapsed:)` call site in `CondensedSidebar` to pass `onToggleCollapse: { withAnimation(.easeInOut(duration: 0.15)) { onToggleCollapse(workspace.id) } }` and drop the `onSelect: { selectedWorkspaceID = ... }` closure.
- [ ] 2.4 Verify by inspection that `selectedWorkspaceID` is only written from pane-row taps (`onSelectPane`) and from context-menu actions, not from the workspace row.

## 3. Replace Tooltips With Native `.help()`

- [ ] 3.1 Apply `.help(workspace.name)` to `WorkspaceRailRow`'s outer modifier chain.
- [ ] 3.2 Apply `.help(pane.displayName)` to `PaneRailRow`.
- [ ] 3.3 Apply `.help(tooltip)` to `CondensedRowView` (used for branch section rows).
- [ ] 3.4 Apply `.help("Expand sidebar")` to the expand button inside `expandHeader`.

## 4. Pin Icon for Pinned Workspace

- [ ] 4.1 Add an `isPinned: Bool` parameter to the `WorkspaceRailRow` struct.
- [ ] 4.2 Change the `Image(systemName:)` expression to `isPinned ? "pin.fill" : (isCollapsed ? "folder" : "folder.fill")`.
- [ ] 4.3 At the `workspaceRow(...)` call site in `CondensedSidebar`, pass `isPinned: workspace.id == pinnedWorkspaceID`.

## 5. Collapsed-Workspace Attention Dot

- [ ] 5.1 Inside `WorkspaceRailRow.body`, add an `.overlay(alignment: .topTrailing)` on the `Image(systemName:)` that renders a `Circle().fill(Color(tokens.attentionColor(for: kind)))` with `.frame(width: 6, height: 6)` ONLY when `isCollapsed == true` AND `workspace.attentionKind != nil`. Offset by a few points (e.g., `.offset(x: 2, y: -2)`) so the dot sits at the icon's outer corner.
- [ ] 5.2 Confirm `Workspace.attentionKind` and `DesignTokens.attentionColor(for:)` are accessible from `CondensedSidebar.swift` without new imports. If `attentionColor(for:)` isn't already present on `DesignTokens`, use the existing `tokens.statusDone` / `tokens.statusBell` / `tokens.statusThinking` branches based on the attention kind directly.
- [ ] 5.3 Verify the dot does NOT render when the workspace is expanded (per-pane rows already show status).

## 6. Add Workspace Button in Rail Chrome

- [ ] 6.1 In `CondensedSidebar.body`, insert a new `addWorkspaceHeader` view between `expandHeader` and the pinned-workspace/scrollContent area. Structure it exactly like `expandHeader`: `HStack` containing a single `BarIconButton(systemImage: "plus", tokens: tokens, accessibilityLabel: "New workspace", help: "New workspace", action: onAddWorkspace)`, framed at `Layout.barHeight`, with `tokens.tabBarBackground` background and a 1px `tokens.border` overlay at the bottom.
- [ ] 6.2 Add an `onAddWorkspace: () -> Void` parameter to `CondensedSidebar`'s property list (it already exists — confirm it's wired).
- [ ] 6.3 Confirm no changes are needed at the `ContentView.condensedSidebar` call site: `onAddWorkspace: handleAddWorkspace` is already passed.

## 7. Selected Workspace Leading Stripe

- [ ] 7.1 In `workspaceSection(_:)`, add `.overlay(alignment: .leading) { if isActive { Rectangle().fill(Color(tokens.textAccent)).frame(width: 2) } }` on the outer `VStack`.
- [ ] 7.2 Keep the existing `tokens.elementHover` background fill for the selected workspace as a secondary cue (do not remove it).
- [ ] 7.3 Sanity-check that the stripe spans the entire section height, including child pane rows when the workspace is expanded, by tracing the view hierarchy.

## 8. Native Scroll Indicator

- [ ] 8.1 In `CondensedSidebar.scrollContent`, change `.scrollIndicators(.never)` to `.scrollIndicators(.automatic)`.

## 9. Build and Verification

- [ ] 9.1 Run `make build`. Fix any compilation errors introduced by parameter additions to `WorkspaceRailRow`.
- [ ] 9.2 Run `swift test`. Ignore the pre-existing signal-10 exit per `CLAUDE.local.md`; verify all Swift Testing suites still pass. No new tests are expected (pure view-layer change).
- [ ] 9.3 Run `make format-check`. Run `make format` if needed.
- [ ] 9.4 Run `make lint`. Resolve any new SwiftLint warnings introduced by this change.

## 10. Manual Verification

- [ ] 10.1 Run `make run`. Switch the sidebar to condensed mode (via `Toggle Sidebar` command or menu bar item).
- [ ] 10.2 Hover each rail row and confirm a native macOS tooltip appears with the correct label (workspace name / pane display name / branch label / "Expand sidebar" / "New workspace").
- [ ] 10.3 Click a workspace folder icon in the rail. Confirm: (a) the workspace toggles between expanded/collapsed; (b) `selectedWorkspaceID` does NOT change (visually: the current terminal in the detail area stays focused on the same pane).
- [ ] 10.4 Collapse a workspace that contains a pane with attention (e.g., a Claude Code pane that finishes a task). Confirm a colored dot appears at the top-trailing corner of the folder icon.
- [ ] 10.5 Pin a workspace from the full sidebar, then switch to condensed mode. Confirm the pinned workspace row renders `pin.fill` in the top pinned section.
- [ ] 10.6 Click the new `+` button in the rail chrome. Confirm a new workspace is created and appears in the rail scroll area.
- [ ] 10.7 Click a pane inside a non-selected workspace and confirm the leading accent stripe moves to that workspace.
- [ ] 10.8 Create enough workspaces to overflow the rail's visible area. Confirm a native scroll indicator appears when scrolling or hovering.
