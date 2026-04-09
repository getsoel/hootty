## ADDED Requirements

### Requirement: Gemini wrapper script is bundled with the app
The app bundle SHALL include an executable file at `Sources/Hootty/Resources/bin/gemini` shipped via SPM resources. The resource bundle's `bin/` directory MUST already be prepended to `PATH` for each pane (this is the existing injection used by the Claude wrapper).

#### Scenario: Wrapper shadows the real binary inside Hootty panes
- **GIVEN** a user with `gemini` installed at `/usr/local/bin/gemini`
- **WHEN** they run `which gemini` inside a Hootty pane
- **THEN** the result points to the bundle's `bin/gemini`

#### Scenario: Wrapper does not shadow outside Hootty
- **GIVEN** a user with `gemini` installed at `/usr/local/bin/gemini`
- **WHEN** they run `which gemini` in a non-Hootty terminal
- **THEN** the result points to `/usr/local/bin/gemini`

### Requirement: Passthrough when not inside Hootty
The wrapper SHALL pass through to the real `gemini` binary unchanged when the `HOOTTY_PANE_ID` environment variable is unset or empty. No env vars or flags SHALL be added.

#### Scenario: Unset HOOTTY_PANE_ID
- **GIVEN** `HOOTTY_PANE_ID` is unset
- **WHEN** the wrapper runs
- **THEN** it execs the real `gemini` binary with the original argv and no additional environment

### Requirement: Real-binary discovery
The wrapper SHALL locate the real `gemini` binary by iterating `PATH` entries, skipping its own directory, and selecting the first executable `gemini` found. If no real binary is located, it SHALL print an error to stderr and exit with status 127.

#### Scenario: Real binary found
- **GIVEN** `/usr/local/bin` and the bundle's `bin/` are both on `PATH`
- **WHEN** the wrapper runs
- **THEN** it resolves `/usr/local/bin/gemini` as the real binary

#### Scenario: Real binary missing
- **GIVEN** no `gemini` exists on `PATH` outside the bundle directory
- **WHEN** the wrapper runs
- **THEN** it prints `"Error: gemini not found in PATH"` to stderr
- **AND** exits with status `127`

### Requirement: Session marker injection via system settings override
When `HOOTTY_PANE_ID` is set, the wrapper SHALL write a JSON settings file to a Hootty-managed location and set `GEMINI_CLI_SYSTEM_SETTINGS_PATH` to point at that file before executing the real `gemini` binary. The settings file MUST contain a `SessionStart` hook and a `CwdChanged` hook.

#### Scenario: Settings file is written before exec
- **WHEN** the wrapper runs inside a Hootty pane
- **THEN** a settings JSON file exists at the path referenced by `GEMINI_CLI_SYSTEM_SETTINGS_PATH`
- **AND** the file contains a `SessionStart` hook invoking `hootty-session-hook`
- **AND** the file contains a `CwdChanged` hook invoking `hootty-cwd-hook`

### Requirement: Session hook emits OSC 9 marker to the terminal
The `hootty-session-hook` executable (shared between Gemini and Codex wrappers) SHALL emit an OSC 9 escape sequence of the form `\e]9;hootty:session:<pane-id>\a` directly to `/dev/tty`. Writing to stdout is NOT sufficient because Gemini CLI consumes hook stdout as a structured response channel.

#### Scenario: Marker written to controlling terminal
- **WHEN** `hootty-session-hook` runs with `HOOTTY_PANE_ID` set
- **THEN** the sequence `\e]9;hootty:session:<HOOTTY_PANE_ID>\a` is written to `/dev/tty`
- **AND** nothing is written to stdout

### Requirement: Cwd hook emits OSC 7 on working-directory change
The `hootty-cwd-hook` executable (shared between Gemini and Codex wrappers) SHALL emit an OSC 7 escape sequence of the form `\e]7;file://<host><path>\a` directly to `/dev/tty` reflecting the current working directory reported by the agent CLI. This enables worktree detection in Hootty's sidebar while the agent is running.

#### Scenario: Cwd update written to controlling terminal
- **WHEN** `hootty-cwd-hook` runs with the new cwd available
- **THEN** the corresponding OSC 7 sequence is written to `/dev/tty`

### Requirement: Existing user hooks are preserved
The wrapper's injection SHALL NOT remove or override user-defined hooks in `~/.gemini/settings.json` or project-level `.gemini/settings.json`. Gemini's layered merge rules combine all tiers additively, so Hootty's system-tier hooks run alongside user hooks.

#### Scenario: User hook runs alongside Hootty hook
- **GIVEN** a user has a `SessionStart` hook in `~/.gemini/settings.json`
- **WHEN** Gemini starts inside a Hootty pane
- **THEN** both the user's hook and Hootty's hook run at session start
