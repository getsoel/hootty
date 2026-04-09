## ADDED Requirements

### Requirement: Codex wrapper script is bundled with the app
The app bundle SHALL include an executable file at `Sources/Hootty/Resources/bin/codex` shipped via SPM resources. The resource bundle's `bin/` directory MUST already be prepended to `PATH` for each pane (this is the existing injection used by the Claude wrapper).

#### Scenario: Wrapper shadows the real binary inside Hootty panes
- **GIVEN** a user with `codex` installed at `/usr/local/bin/codex`
- **WHEN** they run `which codex` inside a Hootty pane
- **THEN** the result points to the bundle's `bin/codex`

#### Scenario: Wrapper does not shadow outside Hootty
- **GIVEN** a user with `codex` installed at `/usr/local/bin/codex`
- **WHEN** they run `which codex` in a non-Hootty terminal
- **THEN** the result points to `/usr/local/bin/codex`

### Requirement: Passthrough when not inside Hootty
The wrapper SHALL pass through to the real `codex` binary unchanged when the `HOOTTY_PANE_ID` environment variable is unset or empty. No env vars or flags SHALL be added.

#### Scenario: Unset HOOTTY_PANE_ID
- **GIVEN** `HOOTTY_PANE_ID` is unset
- **WHEN** the wrapper runs
- **THEN** it execs the real `codex` binary with the original argv and no additional environment

### Requirement: Real-binary discovery
The wrapper SHALL locate the real `codex` binary by iterating `PATH` entries, skipping its own directory, and selecting the first executable `codex` found. If no real binary is located, it SHALL print an error to stderr and exit with status 127.

#### Scenario: Real binary found
- **GIVEN** `/usr/local/bin` and the bundle's `bin/` are both on `PATH`
- **WHEN** the wrapper runs
- **THEN** it resolves `/usr/local/bin/codex` as the real binary

#### Scenario: Real binary missing
- **GIVEN** no `codex` exists on `PATH` outside the bundle directory
- **WHEN** the wrapper runs
- **THEN** it prints `"Error: codex not found in PATH"` to stderr
- **AND** exits with status `127`

### Requirement: CODEX_HOME isolation strategy
When `HOOTTY_PANE_ID` is set, the wrapper SHALL NOT mutate the user's `~/.codex/` directory. Instead, it SHALL prepare a Hootty-managed directory at `${XDG_CACHE_HOME:-$HOME/Library/Caches}/hootty/codex-home/`, point `CODEX_HOME` at that directory, and exec the real `codex` binary with `CODEX_HOME` set in the environment.

#### Scenario: User's codex home is untouched
- **GIVEN** a user's `~/.codex/config.toml` contains custom settings
- **WHEN** the wrapper runs
- **THEN** the contents of `~/.codex/` are unchanged after wrapper execution
- **AND** the real `codex` process sees `CODEX_HOME` pointing at the Hootty-managed directory

#### Scenario: Hootty directory is created on first use
- **GIVEN** `${XDG_CACHE_HOME:-$HOME/Library/Caches}/hootty/codex-home/` does not exist
- **WHEN** the wrapper runs
- **THEN** the directory is created with mode `0700`

### Requirement: User codex files are symlinked into the Hootty directory
The wrapper SHALL symlink every entry in the user's `~/.codex/` directory into the Hootty-managed directory, EXCEPT for `config.toml` and `hooks.json`, which are managed by Hootty. Symlinks MUST be recreated on each run to reflect user changes.

#### Scenario: Arbitrary user file is reachable
- **GIVEN** a file at `~/.codex/mcp-servers/my-server.json`
- **WHEN** the wrapper runs
- **THEN** `${HOOTTY_CODEX_HOME}/mcp-servers/my-server.json` exists and resolves (via symlink) to the user's file

#### Scenario: Hootty-managed files are not symlinked
- **GIVEN** a file at `~/.codex/config.toml`
- **WHEN** the wrapper runs
- **THEN** `${HOOTTY_CODEX_HOME}/config.toml` is a regular file (not a symlink) written by Hootty

### Requirement: Merged config.toml enables the codex_hooks feature
The wrapper SHALL write `${HOOTTY_CODEX_HOME}/config.toml` as a merge of the user's `~/.codex/config.toml` (if present) plus `features.codex_hooks = true`. User settings MUST win over Hootty's defaults except for the `features.codex_hooks` key, which Hootty MUST force to `true`.

#### Scenario: Feature flag is enabled
- **GIVEN** any state of `~/.codex/config.toml`
- **WHEN** the wrapper runs
- **THEN** the resulting `${HOOTTY_CODEX_HOME}/config.toml` contains `features.codex_hooks = true`

#### Scenario: User settings are preserved
- **GIVEN** a `~/.codex/config.toml` containing `model = "o4-mini"` and `features.other_flag = true`
- **WHEN** the wrapper runs
- **THEN** the resulting `${HOOTTY_CODEX_HOME}/config.toml` contains `model = "o4-mini"` and `features.other_flag = true` and `features.codex_hooks = true`

### Requirement: Hooks JSON injects SessionStart and PostToolUse entries
The wrapper SHALL write `${HOOTTY_CODEX_HOME}/hooks.json` as a merge of the user's `~/.codex/hooks.json` (if present) plus a `SessionStart` hook invoking `codex-session-hook` and a `PostToolUse` (matcher: shell/bash) hook invoking `codex-cwd-hook`. User-defined hooks MUST be preserved.

#### Scenario: Hooks file contains Hootty entries
- **GIVEN** no pre-existing `~/.codex/hooks.json`
- **WHEN** the wrapper runs
- **THEN** `${HOOTTY_CODEX_HOME}/hooks.json` exists and contains a `SessionStart` entry invoking `codex-session-hook`
- **AND** a `PostToolUse` entry invoking `codex-cwd-hook`

#### Scenario: User hooks are preserved
- **GIVEN** a `~/.codex/hooks.json` containing a user-defined `Stop` hook
- **WHEN** the wrapper runs
- **THEN** the resulting `${HOOTTY_CODEX_HOME}/hooks.json` contains both the user's `Stop` hook and Hootty's `SessionStart` / `PostToolUse` entries

### Requirement: Session hook emits OSC 9 marker to the terminal
The `codex-session-hook` executable SHALL emit an OSC 9 escape sequence of the form `\e]9;hootty:session:<pane-id>\a` directly to `/dev/tty`. Writing to stdout is NOT sufficient.

#### Scenario: Marker written to controlling terminal
- **WHEN** `codex-session-hook` runs with `HOOTTY_PANE_ID` set
- **THEN** the sequence `\e]9;hootty:session:<HOOTTY_PANE_ID>\a` is written to `/dev/tty`
- **AND** nothing is written to stdout

### Requirement: Cwd hook emits OSC 7 on tool execution
The `codex-cwd-hook` executable SHALL emit an OSC 7 escape sequence reflecting the cwd reported by Codex after each `PostToolUse` (shell tool) event, written directly to `/dev/tty`. This enables worktree detection in Hootty's sidebar while Codex is running.

#### Scenario: Cwd update written to controlling terminal
- **WHEN** `codex-cwd-hook` runs with a cwd available in its input
- **THEN** the corresponding OSC 7 sequence is written to `/dev/tty`

### Requirement: Documented limitation — approval-prompt attention not delivered
The wrapper SHALL NOT attempt to deliver `needsAttention` signals for Codex approval prompts. This is a known and documented limitation, not a defect: Codex's hook lifecycle exposes no approval-specific event. `PreToolUse` (the closest candidate) fires for every tool call, regardless of whether approval is required, and would produce excessive false-positive attention signals.

#### Scenario: Approval prompt does not fire attention
- **GIVEN** a Codex session running in an unfocused Hootty pane
- **WHEN** Codex pauses on an approval prompt
- **THEN** `pane.attentionKind` is NOT set to `.done`
- **AND** the pane's state remains `thinking` until the title or process state changes
