## MODIFIED Requirements

### Requirement: Menu Placement

The Profile menu SHALL be rendered as a dedicated top-level `CommandMenu("Profile")` in the SwiftUI `.commands` block, placed after the `Workspace` menu in natural order. In the final menu bar ordering, Profile appears between `Workspace` and the system-provided `Window` menu.

#### Scenario: Profile menu placed after Workspace

- **WHEN** the app launches
- **THEN** the menu bar shows `Workspace` immediately before `Profile`, and `Profile` immediately before the system `Window` menu
