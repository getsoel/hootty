## ADDED Requirements

### Requirement: Active Profile Name in Titlebar

`ContentView.titleBar` SHALL display the active profile's name as a text label positioned immediately after the 78pt traffic-light reserved space and before the leading `Spacer()`. The label SHALL derive its typography from `TypeScale` and its color from `DesignTokens.from(theme)`.

#### Scenario: Name is visible on launch

- **WHEN** the app launches with any profile active
- **THEN** the titlebar displays that profile's name to the right of the traffic lights

#### Scenario: Name updates on switch

- **WHEN** the user switches to a different profile
- **THEN** the titlebar label updates to show the newly active profile's name without any layout shift of surrounding titlebar elements

#### Scenario: Name updates on rename

- **WHEN** the active profile is renamed
- **THEN** the titlebar label updates to the new name on the next SwiftUI render pass

### Requirement: Titlebar Typography and Color

The profile name label SHALL use `TypeScale.bodySize` and render in a muted foreground color derived from `DesignTokens` (e.g., `tokens.text` or `tokens.textMuted`). The label MUST NOT hardcode font sizes or colors.

#### Scenario: Theme change updates label color

- **WHEN** the theme changes (e.g., via a profile switch that swaps to a different theme)
- **THEN** the label's foreground color updates to the new theme's token-derived color

### Requirement: Non-Interference With Existing Titlebar Content

The profile name label SHALL NOT interfere with the existing titlebar content (traffic-light spacer, memory monitor, spacers, padding). The titlebar height and overall layout SHALL remain governed by `Layout.barHeight`, and the label MUST NOT cause the titlebar to exceed that height.

#### Scenario: Memory monitor still renders

- **WHEN** the memory monitor is active and the profile name is displayed
- **THEN** both elements are visible in the titlebar, the memory monitor retains its trailing position, and the titlebar height equals `Layout.barHeight`

#### Scenario: Traffic lights unaffected

- **WHEN** the profile name label is added
- **THEN** the 78pt reserved leading space for traffic lights is preserved and the standard window buttons are not obscured
