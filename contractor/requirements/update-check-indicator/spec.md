## ADDED Requirements

### Requirement: Titlebar pill placement
The update indicator SHALL render as a `TitlebarChip`-styled pill in the titlebar HStack of `ContentView`, positioned immediately after the activity-monitor chip so it appears to the right of the memory readout.

#### Scenario: Outdated build while activity monitor is visible
- **WHEN** the update service reports an outdated build and `memoryMonitor.memoryMB > 0`
- **THEN** the pill is rendered in the titlebar to the right of the activity-monitor chip
- **AND** shares the visual treatment of the existing `TitlebarChip`

#### Scenario: Outdated build while activity monitor is hidden
- **WHEN** the update service reports an outdated build and the activity-monitor chip is not shown
- **THEN** the pill still renders in the titlebar in the same slot (right-aligned after the spacer)

#### Scenario: Up-to-date build
- **WHEN** the update service reports the app is up-to-date
- **THEN** no update pill is rendered anywhere in the titlebar

### Requirement: Pill label
The pill SHALL label itself with text that communicates a newer version is available, including the remote version number.

#### Scenario: Displaying the remote version
- **WHEN** the remote latest version is `0.3.1`
- **THEN** the pill's visible text MUST include the string `0.3.1`

#### Scenario: Accessibility hint
- **WHEN** assistive technology inspects the pill
- **THEN** it exposes a help/tooltip string that explains clicking will copy the brew upgrade command

### Requirement: Click action copies brew command
Clicking the pill SHALL copy the exact string `brew upgrade --cask hootty` to the system pasteboard and provide a short confirmation.

#### Scenario: User clicks the pill
- **WHEN** the user clicks the pill
- **THEN** the general `NSPasteboard` is cleared and set to the string `brew upgrade --cask hootty`
- **AND** a transient confirmation is surfaced to the user (e.g. a toast, label swap, or equivalent in-UI feedback) for a brief duration

#### Scenario: Repeated clicks
- **WHEN** the user clicks the pill more than once in succession
- **THEN** each click re-writes the clipboard and re-triggers the confirmation without error

### Requirement: Pill reactivity
The pill SHALL react to changes in the update service's observable state so that a check completing mid-session surfaces the indicator without requiring a relaunch.

#### Scenario: Update detected during a running session
- **WHEN** the app is running, a new version is released, and the throttle window allows a new check that detects it
- **THEN** the titlebar pill appears without a relaunch

#### Scenario: User opts out after indicator is shown
- **WHEN** the indicator is visible and the user disables the preference
- **THEN** the pill is removed on the next render pass
