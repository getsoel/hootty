## Why

The condensed sidebar rail is meant to be the "at-a-glance, minimum-width" view of the workspace sidebar, but in its current state it is effectively unusable. Clicking a workspace folder icon is silently broken (it only selects, never toggles collapse). Tooltips don't render because the custom overlay is clipped by the detail view's layer ordering in `ContentView.workspacesContent`, leaving users staring at a column of identical folder icons with no way to tell which workspace is which. Collapsed workspaces hide all attention state — the one thing a condensed rail exists to surface — so monitoring a running agent means expanding the sidebar every time. And basic affordances like adding a workspace require right-clicking empty rail space, which nobody will discover. This change does a single focused pass to make the rail actually work.

## What Changes

- **Fix click-to-collapse bug:** Clicking a workspace folder icon in `WorkspaceRailRow` MUST always toggle that workspace's collapsed state (currently it only sets `selectedWorkspaceID`). Selection happens by clicking a pane inside the workspace, matching the spec-literal reading of `condensed-sidebar-rail/spec.md:37`.
- **Replace broken tooltip with `.help()`:** Delete `RailTooltipModifier` and `railTooltip(_:tokens:isHovered:)` in `CondensedSidebar.swift`. Apply `.help(text)` directly to every row (workspace, branch section, pane, expand button, add button). This uses the native macOS tooltip bubble, which renders in a platform window above the detail view and is unaffected by the `ContentView` ZStack layer ordering that currently hides the custom overlay.
- **Collapsed-workspace attention summary:** When a workspace is collapsed AND has at least one unfocused pane with attention, `WorkspaceRailRow` MUST overlay a small `StatusDotView`-style indicator on the folder icon. The dot color MUST follow the existing dominant-attention priority exposed by `Workspace.attentionKind` (thinking > done > bell). The indicator MUST NOT appear when the workspace is expanded (per-pane rows already convey the same information).
- **Pin icon for pinned workspace:** `WorkspaceRailRow` MUST render `pin.fill` instead of `folder.fill` / `folder` when the workspace is pinned, matching the full sidebar's `WorkspaceRow.swift:26` behavior. The rail already hoists the pinned workspace into a separate top section; this completes the visual parity.
- **Add-workspace button:** A new "+" icon row MUST appear between the expand-sidebar header and the workspace scroll list. Clicking it calls `onAddWorkspace`. The row uses `BarIconButton` styling at the same 28pt row height as other rail rows, with `.help("New workspace")`.
- **Selection leading stripe:** The currently-selected workspace's rail section MUST render a 2pt leading accent stripe (`tokens.textAccent`) spanning the workspace row. This replaces the current `tokens.elementHover` background-fill selection cue, which is too subtle to read at rail width. Pane rows inside the selected workspace retain their existing `elementSelected` background for the focused pane.
- **Native scroll indicator:** Change `.scrollIndicators(.never)` on the condensed scroll view to `.scrollIndicators(.automatic)` so tall workspace lists show the standard macOS scrollbar on hover. The full sidebar keeps its custom `SidebarScrollbar` — the rail doesn't have room for that and the native indicator is sufficient here.
- **Header row height alignment:** The expand header uses `Layout.barHeight` (38pt). The new add-workspace row uses the same 38pt height so the top chrome reads as a coherent two-button stack. Scrollable rows below remain at 28pt min-height.

Non-goals (explicitly out of scope for this change):

- No attention filter strip in condensed mode. Users wanting to filter expand the sidebar.
- No drag-and-drop on rail rows (already excluded by spec).
- No layout-thumbnail toggle.
- No changes to the full (`.full` mode) sidebar.
- No new keyboard shortcuts.

## Capabilities

### New Capabilities

None. This change iterates on an existing capability.

### Modified Capabilities

- `condensed-sidebar-rail`: Multiple requirement-level changes — (1) click semantics on workspace rows change from "select" to "toggle collapse"; (2) tooltip mechanism changes from a custom `railTooltip` overlay to `.help()`; (3) collapsed workspace rows gain a mandatory attention-summary dot (the spec already calls for this but it is unimplemented); (4) pinned workspaces render with `pin.fill` instead of `folder.fill`; (5) a new "+" add-workspace row is added below the expand button; (6) the selected workspace gains a leading accent stripe; (7) scroll indicators change from `.never` to `.automatic`. A delta spec will capture each of these behavior changes.

## Impact

**Code:**
- `Sources/Hootty/Views/CondensedSidebar.swift` — primary file for all changes.
  - `WorkspaceRailRow`: wire `onTapGesture` to toggle collapse (new `onToggleCollapse` parameter); add `folder`/`folder.fill`/`pin.fill` icon selection; add `.overlay(alignment: .topTrailing)` attention dot; replace `.railTooltip(...)` with `.help(workspace.name)`.
  - `PaneRailRow`, `CondensedRowView`, `expandHeader` button: replace `.railTooltip(...)` with `.help(...)`.
  - New add-workspace row rendered between `expandHeader` and `scrollContent`.
  - New leading-stripe overlay on `workspaceSection` when `isActive`.
  - `scrollContent`: change `.scrollIndicators(.never)` → `.scrollIndicators(.automatic)`.
  - Delete `RailTooltipModifier` struct and the `railTooltip(_:tokens:isHovered:)` extension.
  - `workspaceRow(...)` call site: pass `onToggleCollapse: { onToggleCollapse(workspace.id) }` instead of (or in addition to) the current `onSelect` wiring. Per option A, click does not change selection at all — selection moves only when the user clicks a pane.
- `Sources/Hootty/Views/ContentView.swift` — no changes. `CondensedSidebar` already receives `onAddWorkspace`, `onToggleCollapse`, etc.; the existing wiring is reused.
- `Sources/HoottyCore/` — no changes. `Workspace.attentionKind` already returns the dominant unfocused-pane attention; the rail consumes it directly.

**APIs:** None exposed externally. All changes are view-layer.

**Dependencies:** None.

**User-visible behavior:**
- Clicking a workspace folder in the rail now expands/collapses it instead of selecting it. To select a workspace from the rail, click a pane inside it.
- Tooltips now appear as standard macOS yellow tooltip bubbles on hover (previously invisible).
- Collapsed workspaces show a colored status dot when their child panes have attention.
- The pinned workspace shows a pin icon.
- A "+" button in the rail top chrome creates a new workspace.
- The selected workspace has a visible accent stripe on its leading edge.
- Native scrollbar appears on hover when the workspace list overflows.

**Systems:** None. No ghostty interaction, no config, no persistence, no sound, no agent detection.

**Risk / compatibility:**
- The click-semantics change is a user-visible behavior change. Anyone who has built a muscle memory of "click folder = select workspace" in condensed mode will need to adjust. Mitigated by the fact that the current behavior was silently broken anyway (no collapse feedback, no tooltips) and matches the full sidebar's direct-folder-tap behavior at `WorkspaceRow.swift:30-35`.
- `.help()` tooltips can't be custom-themed. Acceptable trade-off; spec explicitly asks for `.help()`.
