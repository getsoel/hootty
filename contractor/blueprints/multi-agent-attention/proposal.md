## Why

Hootty's attention-state system (thinking indicator, `.done` attention kind, sidebar filters) is hardcoded to detect Claude Code via `ClaudeTitleParser` and a Claude-specific wrapper script. Users running Google Gemini CLI or OpenAI Codex CLI get none of these affordances — no thinking spinner, no done badge, no sidebar filtering — even though both tools emit distinguishable terminal-title signals and ship hook systems we can integrate with. This change generalizes the detection layer so any agent CLI can light up the same tool-agnostic UI.

## What Changes

- **BREAKING** (persistence): `Pane.claudeSessionID` is renamed to `Pane.agentSessionID`. Codable migration reads the legacy key as a fallback when decoding older workspace files.
- New `Sources/HoottyCore/Agents/` module housing: `AgentPresence` enum (`thinking | idle | needsAttention`), `AgentTitleDetector` protocol, and an `AgentTitleDetection` registry that runs all detectors against each title change.
- New `GeminiTitleParser` recognizing `◇` (idle), `✦` / `⏲` (thinking), `✋` (needs attention). The `✋` → `needsAttention` path is a new signal: the agent explicitly asserts "user input needed" rather than Hootty inferring it from focus transitions.
- New `CodexTitleParser` recognizing Braille spinner glyphs as thinking. Duplicates `ClaudeTitleParser`'s leading-char rule — kept as a discoverable standalone file despite the overlap.
- `ClaudeTitleParser` is moved into the new module and conforms to `AgentTitleDetector`. Its existing behavior is preserved.
- `PaneEventHandler.handleTitleChange` gains an **implicit-idle branch**: when a pane's title no longer matches any detector *and* the pane was previously thinking under an auto-detected session, fire `endThinking()` instead of clearing the session marker. This is required because Codex has no idle glyph — its title collapses to the plain project name when idle.
- `AgentPresence.needsAttention` routes through `handlePaneNeedsAttention`, which only sets `.done` attention **when the pane is unfocused** (consistent with existing `.bell` / `.done` semantics — no double-notification for a user already looking at the pane).
- UI relabeling: `AttentionKind.done.displayName` changes from `"Claude Done"` to `"Agent Done"`. `StatusDotView(isClaudeSession:)` renames to `isAgentSession:`. No visual changes — every tool produces the same indicators.
- New wrapper script `Sources/Hootty/Resources/bin/gemini` injecting `SessionStart` + `CwdChanged` hooks via `GEMINI_CLI_SYSTEM_SETTINGS_PATH` env var pointing at a Hootty-managed settings file. Hooks emit OSC sequences to `/dev/tty` (since Gemini consumes hook stdout).
- New wrapper script `Sources/Hootty/Resources/bin/codex` using a **`CODEX_HOME` isolation strategy**: creates `$XDG_CACHE_HOME/hootty/codex-home/`, symlinks the user's existing `~/.codex/` files into it, overlays merged `config.toml` (adding `features.codex_hooks = true`) and `hooks.json` (adding SessionStart + PostToolUse entries), and execs `codex` with `CODEX_HOME` pointed at the Hootty directory. Zero mutation of user files.
- Codex wrapper does **not** solve the approval-prompt `needsAttention` gap: Codex's hook lifecycle has no approval-specific event, only `PreToolUse` which fires for every tool call. Documented as a known limitation.

## Capabilities

### New Capabilities
- `multi-agent-attention-detection`: Pluggable agent title detection. Defines the `AgentTitleDetector` protocol, the `AgentPresence` state model, per-agent parsers (Claude, Gemini, Codex), the `Pane.agentSessionID` model rename with Codable migration, the implicit-idle title-change handling, and the `needsAttention` routing rules.
- `gemini-cli-wrapper`: Bundled wrapper script intercepting `gemini` invocations inside Hootty panes. Injects a `SessionStart` hook (session marker via OSC 9) and a `CwdChanged` hook (OSC 7) via `GEMINI_CLI_SYSTEM_SETTINGS_PATH`. Passes through unchanged when `HOOTTY_PANE_ID` is unset.
- `codex-cli-wrapper`: Bundled wrapper script intercepting `codex` invocations inside Hootty panes. Uses `CODEX_HOME` isolation to inject `features.codex_hooks = true` and a `hooks.json` with `SessionStart` (session marker) and `PostToolUse` bash-matcher (cwd tracking). Symlinks the user's existing `~/.codex/` contents into the Hootty-managed directory so user config (API keys, model choice, MCP servers) continues to work. Passes through unchanged when `HOOTTY_PANE_ID` is unset.

### Modified Capabilities
<!-- None — no existing requirements govern attention-state detection. -->

## Impact

**Code**:
- `Sources/HoottyCore/ClaudeTitleParser.swift` → moved to `Sources/HoottyCore/Agents/ClaudeTitleParser.swift`, conforms to new protocol.
- `Sources/HoottyCore/Agents/` (new directory): `AgentPresence.swift`, `AgentTitleDetector.swift`, `GeminiTitleParser.swift`, `CodexTitleParser.swift`.
- `Sources/HoottyCore/Pane.swift`: rename `claudeSessionID` → `agentSessionID`, add Codable fallback reading the legacy key.
- `Sources/HoottyCore/PaneEventHandler.swift`: `handleTitleChange` rewritten to use `AgentTitleDetection.detect`, adds the implicit-idle branch and `needsAttention` routing.
- `Sources/Hootty/Views/TerminalPaneView.swift`: update title-change closure to use `AgentTitleDetection.stripPrefix` and `pane.agentSessionID`.
- `Sources/Hootty/Views/SidebarPaneRow.swift`, `PaneGroupTabBar.swift`, `CondensedSidebar.swift`: rename `isClaudeSession:` → `isAgentSession:` at call sites.
- `Sources/Hootty/Views/StatusDotView.swift`: rename the parameter.
- `Sources/HoottyCore/Pane.swift` `AttentionKind.done.displayName`: `"Claude Done"` → `"Agent Done"`.
- `Sources/Hootty/Resources/bin/gemini`: new wrapper. Uses the shared `hootty-session-hook` and `hootty-cwd-hook` scripts (also consumed by the Codex wrapper).
- `Sources/Hootty/Resources/bin/codex`: new wrapper sharing the same `hootty-session-hook` / `hootty-cwd-hook` helpers.
- `Sources/Hootty/Resources/bin/hootty-session-hook`, `hootty-cwd-hook`: new shared hook scripts emitting OSC 9 / OSC 7 to `/dev/tty`.

**Persistence**: Existing workspace files storing `claudeSessionID` decode successfully via the Codable fallback. No user-visible migration step.

**Tests**:
- `Tests/HoottyCoreTests/ClaudeTitleParserTests.swift`: preserved, may be adjusted for the new module path.
- New `Tests/HoottyCoreTests/GeminiTitleParserTests.swift`.
- New `Tests/HoottyCoreTests/CodexTitleParserTests.swift`.
- New `Tests/HoottyCoreTests/AgentTitleDetectionTests.swift` covering detector registry order and `stripPrefix` fan-out.
- `Tests/HoottyCoreTests/PaneEventHandlerTests.swift`: new cases for implicit-idle (Codex), `needsAttention` focus gating (Gemini `✋`), and the legacy `claudeSessionID` decode path.
- `Tests/HoottyCoreTests/IntegrationTests.swift`: persist/restore round-trip with legacy-key workspace fixture.

**Docs**:
- `docs/HOOKS.md`: rewritten to cover multi-agent detection, the three wrapper scripts, and the Codex `CODEX_HOME` isolation strategy.
- `CLAUDE.md`: update the Architecture tree to mention the new `Agents/` module and the renamed Pane field.

**Dependencies**: None. All changes stay within the existing SPM targets and do not require new third-party packages. Hook injection reuses the existing OSC 9 → `GHOSTTY_ACTION_DESKTOP_NOTIFICATION` path already wired for Claude Code.

**External systems**: Wrapper scripts assume `gemini` and `codex` binaries exist on `PATH`. If not present, wrappers pass through with a helpful error (same pattern as the existing Claude wrapper).

**Known limitations (intentional)**:
- Codex approval-prompt attention is not delivered — Codex exposes no lifecycle event at the approval point. Would require upstream support for a `ToolApprovalRequest` event.
- When a user disables Gemini's dynamic window title (`settings.ui.hideWindowTitle`), title-based state detection degrades — session existence is still inferred via the hook-based OSC 9 marker once the wrapper is in place.
- Claude Code and OpenAI Codex both use Braille spinners; the detector registry cannot distinguish them from the title alone. Intentional — the UI is tool-agnostic and `Pane.agentKind` is deliberately not stored.
