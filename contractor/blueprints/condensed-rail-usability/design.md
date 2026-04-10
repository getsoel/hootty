## Context

The condensed sidebar rail (`Sources/Hootty/Views/CondensedSidebar.swift`) was built to spec but multiple behaviors are broken or missing in practice:

- `WorkspaceRailRow.onTapGesture` wires only to `selectedWorkspaceID = workspace.id`, never toggling collapse state. The spec requires clicks to toggle collapse.
- `RailTooltipModifier` tries to render its own themed tooltip bubble via `.overlay(alignment: .trailing)` with `.offset(x: Spacing.sm)` and `.frame(maxWidth: .infinity, alignment: .leading)`. Two issues kill visibility: (a) in `ContentView.workspacesContent` the `ZStack` draws the sidebar first and the detail view last, so any overlay extending past `Layout.condensedSidebarWidth` (38pt) is occluded by the detail view; (b) the overlay layout itself combines contradictory modifiers and the outer `.clipped()` on the workspaces container trims overflow anyway.
- `WorkspaceRailRow` never consults `Workspace.attentionKind`, so collapsed workspaces carry no at-a-glance status information — defeating the whole purpose of the rail as a monitoring surface.
- The pinned workspace is hoisted into a top section via `CondensedSidebar.workspaceSection`, but its rail row still renders `folder.fill`/`folder` instead of the `pin.fill` the full sidebar uses.
- There is no add-workspace affordance in the rail other than an undiscoverable right-click on empty space.
- Selection cue relies on a subtle `tokens.elementHover` background fill applied to the whole workspace section, which is close to indistinguishable at rail width on Catppuccin palettes.
- `.scrollIndicators(.never)` leaves tall workspace lists with no visible indication they can scroll.

The existing legacy spec at `contractor/requirements/condensed-sidebar-rail/spec.md` was authored in a section-plus-bullet format that predates the `### Requirement: ... #### Scenario:` convention this repo now uses. The delta in `requirements/condensed-sidebar-rail/spec.md` of this blueprint is expressed in the current convention and will need a small hand-merge at archive time (see Migration Plan).

`Workspace.attentionKind` (`Sources/HoottyCore/Workspace.swift:118-120`) already returns the dominant unfocused-pane attention via `AttentionCounts.firstAttentionKind`, so no HoottyCore changes are needed.

## Goals / Non-Goals

**Goals:**

- Fix the three functional bugs (click-to-collapse, tooltip visibility, missing collapsed-workspace attention dot) in the minimum code that restores spec-compliance.
- Add a small set of new affordances (pin icon, add button, selection stripe, native scroll indicator) that make the rail usable as a monitoring and navigation surface without touching `HoottyCore` or the full sidebar.
- Keep every change confined to `Sources/Hootty/Views/CondensedSidebar.swift`.
- Preserve the rail's existing width of `Layout.condensedSidebarWidth` (38pt).

**Non-Goals:**

- Filter pills, drag-and-drop, layout thumbnails, or any other affordance that would push the rail past its current 38pt width.
- Custom-themed tooltips matching the design-token palette. Native `.help()` is explicitly chosen to sidestep the `ContentView` layer-ordering problem without introducing a `PreferenceKey` → top-level overlay plumbing change.
- Keyboard shortcuts for the new add-workspace button. The existing palette entry and full-sidebar "+" button cover keyboard-driven creation.
- Changes to `ContentView.workspacesContent`, `AppModel`, `Workspace`, or the full `WorkspaceSidebar`. This change is strictly view-local.
- Implementing a new custom scrollbar. The full sidebar's `SidebarScrollbar` is not portable to 38pt width and is explicitly out of scope.

## Decisions

### Decision 1: Tooltip mechanism — `.help()` over custom overlay or preference-key floating label

**Chosen:** Replace `RailTooltipModifier` with `.help(text)` applied directly to each interactive row (workspace, pane, branch section, expand button, add-workspace button).

**Rationale:** `.help()` delegates to AppKit's `NSHelpManager`, which renders the tooltip in a platform-level window that is not clipped by any SwiftUI view's frame or the `ContentView` ZStack layer ordering. It is a one-line change per row, contains zero layout logic, and matches existing spec language that already says "via `.help()`" (existing spec line 64).

**Alternatives considered:**

- **Custom themed floating label via `PreferenceKey`** — Each row reports `(isHovered, text, globalFrame)` up the view hierarchy; `ContentView` renders a single themed label in a top-level `.overlay` with `zIndex(10)` positioned at `globalFrame.maxX + offset`. This would give a design-system-consistent look but introduces cross-file coordination, frame tracking (requires `.onChange(of: geo.frame(in: .global), initial: true)` per the `swiftui.md` rule), and a visibility-on-hover choreography that is fragile with fast mouse movement. Rejected as over-engineered for a fix.
- **Swap ZStack child order in `ContentView`** — Draw the detail view first and sidebar last so sidebar overlays don't get occluded. Would fix the specific clipping issue but risks breaking hit-testing on the detail view's outer regions and the divider, and would need careful audit of the drag handle overlay for the full-mode sidebar. Disproportionate blast radius for a tooltip fix.
- **`NSPopover`** — Overkill for a tooltip, and would need its own hover-delay/dismiss logic.

### Decision 2: Click semantics — toggle-only, no selection change

**Chosen:** Clicking a workspace folder icon in the rail toggles that workspace's `collapsed` state and does nothing else. Selection changes only when the user clicks a pane row inside a workspace.

**Rationale:** In a 38pt rail, single clicks need one unambiguous meaning. The user explicitly chose this option in discussion (option A). This matches a spec-literal reading of the existing `condensed-sidebar-rail/spec.md:37` and preserves user focus when "peeking" at a non-active workspace's contents. The full-sidebar row in `WorkspaceRow.swift:30-35` also toggles on direct folder-icon tap without changing selection, so the behavior is parallel.

**Alternatives considered:**

- **Hybrid (toggle + auto-select-if-not-selected)** — Clicking an inactive workspace would select and expand it in one gesture. More "forgiving" but introduces ambiguity: a user clicking to peek loses their current focus. Rejected per the user's explicit preference.
- **Full-sidebar parity where row body selects and icon toggles** — The condensed rail has no row "body" to speak of; the icon IS the row. Not applicable.

### Decision 3: Attention dot placement — `.overlay(alignment: .topTrailing)` on the folder icon

**Chosen:** When a workspace is collapsed AND `workspace.attentionKind != nil`, render a small 6pt circle filled with `tokens.attentionColor(for: kind)` as `.overlay(alignment: .topTrailing)` on the `Image(systemName:)` folder icon. Hide the dot when the workspace is expanded (the per-pane rows under it already show the same information).

**Rationale:** `Workspace.attentionKind` already returns the dominant unfocused-pane attention using the existing `AttentionCounts.firstAttentionKind` priority (thinking → done → bell), so no new logic is needed. A 6pt circle at the top-trailing corner of a 12pt SF Symbol is visible without overwhelming the icon, and sits inside the 38pt row width with no clipping risk. A thinking workspace uses the static circle (no rotation) in the summary — animating it would compete visually with the per-pane spinner that appears once the user expands the workspace.

**Alternatives considered:**

- **Inline StatusDotView component** — `StatusDotView` exists as a separate view but includes hover affordances and sizing intended for the full sidebar. Importing it would pull in layout assumptions we don't want on a 38pt row. A local `Circle().fill(...)` overlay is simpler.
- **Animated spinner for `thinking`** — Parity with the per-pane thinking spinner would be nicer, but makes the collapsed summary visually noisy when multiple workspaces are thinking simultaneously. Static dot wins on signal-to-noise.
- **Dot adjacent to the folder icon (trailing side, same row)** — Would require a `HStack` layout and push the folder icon off-center in the 38pt row. Overlay keeps the folder centered.

### Decision 4: Add-workspace button placement — second row of non-scrolling chrome

**Chosen:** Insert a new `plus` button as the second row in the rail top chrome, immediately below `expandHeader` and above `scrollContent`. The button uses `BarIconButton` wrapped in a fixed-height 38pt container with `tokens.tabBarBackground` and a 1px `tokens.border` below it, mirroring `expandHeader` exactly. The button is `.help("New workspace")` and invokes `onAddWorkspace`.

**Rationale:** Keeps the button always visible regardless of scroll position, discoverable without right-click, and visually parallel to the expand button directly above it. Placing it inside the scroll view would hide it for users with many workspaces. Placing it at the bottom of the rail would detach it from the other creation-adjacent controls. Two stacked 38pt chrome rows at the top is a clean "header zone" users can visually parse.

**Alternatives considered:**

- **Inside `expandHeader` as a side-by-side button** — 38pt / 2 = 19pt per button is cramped and visually worse than current styling.
- **Floating at bottom of rail** — Disconnected from other header actions and competes with any future bottom-docked affordances.
- **Right-click context menu only** — Currently the case, and is the reason "New Workspace" is undiscoverable. Rejected.

### Decision 5: Selection leading stripe — 2pt `Rectangle` overlay on `workspaceSection`

**Chosen:** Apply a `.overlay(alignment: .leading)` on the `workspaceSection` VStack (which wraps the workspace row + any expanded child pane rows) containing a `Rectangle().fill(Color(tokens.textAccent)).frame(width: 2)`, gated on `isActive`. Retain the existing `tokens.elementHover` background fill as a secondary cue so the selection reads from both the stripe and a subtle fill.

**Rationale:** An overlay on the entire section spans both the workspace row and its (possibly expanded) child pane rows, creating a continuous vertical accent that clearly demarcates the selected group. `tokens.textAccent` is the app's canonical accent color and carries enough contrast on any Catppuccin variant to read at 2pt. Scoping to the VStack avoids coordinating stripes across sibling views.

**Alternatives considered:**

- **Stripe on the workspace row only** — Disconnects visually from the child pane rows when the workspace is expanded. Worse.
- **Full row background fill swap** — Tried and rejected as the current state; too subtle at rail width.
- **`RoundedRectangle` stripe with rounded corners** — Violates the `design-system.md` rule that sidebar backgrounds use sharp `Rectangle` fills, not rounded.

### Decision 6: Pin icon — direct symbol swap in `WorkspaceRailRow`

**Chosen:** In `WorkspaceRailRow.body`, compute the icon name as `isPinned ? "pin.fill" : (isCollapsed ? "folder" : "folder.fill")`. Plumb `isPinned: Bool` into `WorkspaceRailRow` by passing `workspace.id == pinnedWorkspaceID` from the `workspaceRow(...)` call site in `CondensedSidebar`.

**Rationale:** Minimal plumbing, exact parity with `WorkspaceRow.swift:26`. `CondensedSidebar` already has `pinnedWorkspaceID: UUID?` in its input set and uses it to split the `scrollableWorkspaces` vs `pinnedWorkspace` sections, so the value is locally available.

**Alternatives considered:**

- **Keep folder icon, add a separate tiny pin badge overlay** — Redundant with the top pinned-section placement; the pinned section header already conveys pin status via its hoisted position.

### Decision 7: Scroll indicator — `.automatic` native

**Chosen:** Change `.scrollIndicators(.never)` to `.scrollIndicators(.automatic)` on the condensed `ScrollView`.

**Rationale:** One-line change, uses native macOS indicator, appears only when content overflows, doesn't consume layout space when hidden. No need to port the full sidebar's custom `SidebarScrollbar` (which is built around `sidebarHovered` state and custom drag handling that the rail doesn't need).

**Alternatives considered:**

- **`.scrollIndicators(.visible)`** — Always-visible indicator. Noisy when not needed.
- **Port `SidebarScrollbar`** — Disproportionate work for a 38pt rail; the custom scrollbar's padding and drag affordances assume sidebar width.

## Risks / Trade-offs

- **Tooltip style inconsistency with full sidebar** → The full sidebar uses custom themed tooltips where needed; the rail will use native `.help()` bubbles. Mitigation: acceptable because they appear in different contexts (rail vs. full sidebar) and users don't see both at once. If future work adds themed tooltips elsewhere, revisit via a shared `PreferenceKey` approach.
- **Legacy spec format mismatch at archive time** → The existing `contractor/requirements/condensed-sidebar-rail/spec.md` uses a section-plus-bullet format that can't cleanly receive a `### Requirement:` delta. The delta in this blueprint adds new requirements in the modern format but does not automatically remove the obsolete "MUST NOT display a '+' button" bullet from the legacy spec. Mitigation: the requirements delta explicitly calls out the supersession, and the archive step for this blueprint will need a 1-line manual edit to delete that line from the merged spec (captured in the Migration Plan below).
- **Click-semantics change is user-visible behavior change** → Users who had built a mental model of "click workspace = select" will need to adjust. Mitigation: the prior behavior was already broken in practice because it offered no collapse feedback and no tooltips, so nobody has a working muscle memory for it.
- **`.help()` tooltips have a ~1-second hover delay on macOS** → Slower than the instant hover state. Mitigation: users of the rail are typically monitoring or briefly navigating, not speed-scanning; the spec explicitly calls for `.help()` so this is accepted.
- **Selection stripe may visually clash with the focused pane row's `elementSelected` background** → Overlap is possible when the selected workspace is also expanded and its focused pane shows its own background. Mitigation: the leading stripe is 2pt wide and the focused pane's background already leaves a 2pt margin available at the leading edge. Verify visually during implementation on both a light and a dark Catppuccin theme.

## Migration Plan

No user data migration is needed.

**Spec archive cleanup (one-time at blueprint close):**

At `contractor blueprint close` time, when the delta is merged into `contractor/requirements/condensed-sidebar-rail/spec.md`, manually remove the bullet `- The rail MUST NOT display a "+" button.` from the legacy `### Constraints` section. This is called out in the proposal and requirements delta. No other legacy-spec edits are needed — the remaining legacy bullets (drag-and-drop prohibition, attention badge pills prohibition, layout thumbnails prohibition, filter state behavior) are all unchanged by this blueprint.

**Rollback:**

Revert the single commit on the `contractor/condensed-rail-usability` branch. No persistence, no config, no migrations to undo.

## Open Questions

None. The user explicitly resolved the four open questions from the exploration session:

1. Click semantics → option A (toggle-only, no selection change).
2. Tooltip style → option A (native `.help()`).
3. Filter strip → not at all.
4. Scope → single proposal.
