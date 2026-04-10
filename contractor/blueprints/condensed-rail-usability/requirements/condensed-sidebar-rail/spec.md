## ADDED Requirements

### Requirement: Workspace Click Selects Nothing

Clicking a workspace folder icon in the rail SHALL toggle that workspace's collapsed state ONLY. It SHALL NOT change `selectedWorkspaceID` or shift focus to a pane. Workspace selection in condensed mode SHALL change only when the user clicks a pane row inside a workspace (which selects the workspace AND focuses that pane, via the existing `onSelectPane` callback).

This clarifies the existing "Clicking a workspace folder icon MUST toggle collapse/expand" requirement by specifying that no selection change occurs on workspace taps. The rationale is that in a minimum-width rail, a single click must have one clear meaning; mixing toggle-and-select creates ambiguity when the user wants to peek at a workspace's contents without stealing focus from their current pane.

#### Scenario: Click expanded non-selected workspace

- **WHEN** the user clicks the folder icon of a workspace that is expanded and not currently selected
- **THEN** that workspace becomes collapsed and `selectedWorkspaceID` remains unchanged

#### Scenario: Click collapsed non-selected workspace

- **WHEN** the user clicks the folder icon of a workspace that is collapsed and not currently selected
- **THEN** that workspace becomes expanded and `selectedWorkspaceID` remains unchanged

#### Scenario: Click the currently selected workspace

- **WHEN** the user clicks the folder icon of the workspace that is currently selected
- **THEN** that workspace's collapsed state toggles and `selectedWorkspaceID` remains set to that workspace

#### Scenario: Selecting a workspace via a pane click

- **WHEN** the user clicks a pane row inside a non-selected expanded workspace
- **THEN** `selectedWorkspaceID` updates to that workspace and the clicked pane becomes focused

### Requirement: Pinned Workspace Uses Pin Icon

The workspace rail row SHALL render the SF Symbol `pin.fill` in place of `folder.fill` / `folder` when the workspace is the pinned workspace (i.e., its id equals `AppModel.pinnedWorkspaceID`). The icon color SHALL follow the same selected/muted rule as non-pinned workspace rows. The pinned workspace row SHALL remain in the top-pinned section, above the scroll area, as already required by the Pinned Section requirements.

#### Scenario: Pinned workspace shows pin icon

- **WHEN** a workspace is pinned and the sidebar is in condensed mode
- **THEN** its rail row renders the `pin.fill` SF Symbol instead of any folder variant

#### Scenario: Unpinning restores folder icon

- **WHEN** the user unpins a workspace that was pinned
- **THEN** on the next render, its rail row renders `folder.fill` (if expanded) or `folder` (if collapsed), matching non-pinned workspace rows

### Requirement: Add Workspace Button in Rail Chrome

The condensed rail SHALL display a dedicated "New Workspace" button as the second row of the rail's top chrome, immediately below the `Expand Sidebar` row and above the workspace scroll area. The button SHALL use the SF Symbol `plus`, SHALL be rendered with the same styling as the existing expand button (full-width, `Layout.barHeight` high, `tokens.tabBarBackground` background, 1px `tokens.border` below), and SHALL have the tooltip "New workspace" applied via `.help()`. Clicking the button SHALL invoke the existing `onAddWorkspace` callback that the full sidebar also uses.

The prior constraint "The rail MUST NOT display a '+' button" in the existing Constraints section is SUPERSEDED by this requirement and SHALL be removed from the merged spec at archive time.

#### Scenario: Button is present in condensed mode

- **WHEN** the sidebar is in condensed mode
- **THEN** a `plus` icon button is visible as the second row from the top, directly below the expand-sidebar button and above any workspace rows

#### Scenario: Clicking the button creates a workspace

- **WHEN** the user clicks the add-workspace button
- **THEN** a new workspace is created via the same `onAddWorkspace` path the full sidebar uses, and the new workspace appears in the rail's scroll area

#### Scenario: Button is not rendered in full mode

- **WHEN** the sidebar is in full mode
- **THEN** the condensed rail (and therefore the add-workspace button in the rail) is not rendered; the full sidebar's existing "+" button in its header continues to be the only add-workspace affordance in that mode

### Requirement: Selected Workspace Leading Accent Stripe

The condensed rail SHALL render a 2pt-wide vertical leading accent stripe filled with `tokens.textAccent` along the left edge of the currently-selected workspace's entire section (workspace row plus any expanded child rows underneath). The stripe SHALL replace reliance on `tokens.elementHover` background fill as the primary selection cue; the background fill MAY remain but SHALL NOT be the sole indicator. The stripe SHALL NOT appear on non-selected workspaces.

#### Scenario: Selection stripe on active workspace

- **WHEN** a workspace is the currently selected workspace in condensed mode
- **THEN** a 2pt-wide `tokens.textAccent` stripe is rendered along the leading edge of its workspace section, spanning the workspace row and any visible child pane rows

#### Scenario: No stripe on inactive workspaces

- **WHEN** a workspace is not the currently selected workspace
- **THEN** no leading stripe is rendered on its section

#### Scenario: Stripe moves with selection change

- **WHEN** the user clicks a pane inside a different workspace
- **THEN** the leading stripe disappears from the previously-selected workspace and appears on the newly-selected workspace on the next render

### Requirement: Native Scroll Indicator

The condensed rail's workspace scroll view SHALL use `.scrollIndicators(.automatic)` so that the standard macOS scroll indicator appears during active scrolling or hovering when the content overflows the visible area. The prior `.scrollIndicators(.never)` setting SHALL be removed. The rail SHALL NOT host the custom `SidebarScrollbar` used by the full sidebar; the narrow rail width cannot accommodate it and the native indicator is sufficient.

#### Scenario: Indicator appears on overflow

- **WHEN** the user has enough workspaces that the rail's scroll content exceeds the visible height, and the user hovers over the rail or actively scrolls
- **THEN** the standard macOS scroll indicator is visible along the trailing edge of the scroll area

#### Scenario: No indicator when content fits

- **WHEN** the rail's scroll content fits entirely within the visible height
- **THEN** no scroll indicator is rendered
