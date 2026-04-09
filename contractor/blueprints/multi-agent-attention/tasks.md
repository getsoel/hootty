## 1. Detection layer foundation (Phase 1)

- [x] 1.1 Create `Sources/HoottyCore/Agents/` directory and add `AgentPresence.swift` with the three-case enum (`thinking`, `idle`, `needsAttention`), `Equatable`, `Sendable`.
- [x] 1.2 Add `Sources/HoottyCore/Agents/AgentTitleDetector.swift` defining the `AgentTitleDetector` protocol (static `detect` + static `stripPrefix`) and the `AgentTitleDetection` registry enum with `detect(_:)` and `stripPrefix(_:)` fan-out methods.
- [x] 1.3 Move `Sources/HoottyCore/ClaudeTitleParser.swift` to `Sources/HoottyCore/Agents/ClaudeTitleParser.swift`. Update its signature to conform to `AgentTitleDetector` — rename the existing `parse(_:)` helper to `detect(_:)` and return the new `AgentPresence` type. Preserve the existing Braille / `✳` / `*` semantics exactly.
- [x] 1.4 Create `Sources/HoottyCore/Agents/GeminiTitleParser.swift` implementing detection of `◇` → idle, `✦` → thinking, `⏲` → thinking, `✋` → needsAttention. `stripPrefix` MUST drop the first scalar, any adjacent whitespace, and trailing padding whitespace.
- [x] 1.5 Create `Sources/HoottyCore/Agents/CodexTitleParser.swift` implementing the Braille-only thinking rule (no idle, no needsAttention). Returns `nil` for any title without a Braille prefix.
- [x] 1.6 Register all three detectors in `AgentTitleDetection.detectors` in the order: Gemini, Claude, Codex.

## 2. Model and persistence migration

- [x] 2.1 In `Sources/HoottyCore/Pane.swift`, rename the `claudeSessionID` property to `agentSessionID`. Update the designated initializer parameter name and default.
- [x] 2.2 Update `Pane`'s Codable `init(from:)` to read `agentSessionID` first, falling back to `claudeSessionID` when absent. Add both keys to `CodingKeys` with only `agentSessionID` in `encode(to:)`.
- [x] 2.3 Change `AttentionKind.done.displayName` from `"Claude Done"` to `"Agent Done"`.

## 3. PaneEventHandler rewiring

- [x] 3.1 In `Sources/HoottyCore/PaneEventHandler.swift`, rewrite `handleTitleChange` to use `AgentTitleDetection.detect(_:)`. Replace all `claudeSessionID` references with `agentSessionID`.
- [x] 3.2 Add the detected-presence switch: `.thinking` sets `pane.isThinking = true` and clears attention; `.idle` calls `endThinking`; `.needsAttention` sets `pane.isThinking = false` and routes through `handlePaneNeedsAttention(kind: .done)` so the focus gate applies.
- [x] 3.3 Add the implicit-idle branch: when no detector matches AND `pane.agentSessionID == "auto"` AND `pane.isThinking == true`, invoke `endThinking` while preserving `agentSessionID`. Do NOT clear the session marker on unmatched titles.
- [x] 3.4 When a detector matches and `pane.agentSessionID` is nil, set it to `"auto"` before applying the state.

## 4. UI rename and wiring

- [x] 4.1 In `Sources/Hootty/Views/StatusDotView.swift`, rename the `isClaudeSession` parameter to `isAgentSession`.
- [x] 4.2 Update call sites in `Sources/Hootty/Views/SidebarPaneRow.swift` and `Sources/Hootty/Views/PaneGroupTabBar.swift` to pass `isAgentSession: pane.agentSessionID != nil`.
- [x] 4.3 Update `Sources/Hootty/Views/CondensedSidebar.swift` line 481 to reference `pane.agentSessionID` instead of `claudeSessionID`.
- [x] 4.4 Update `Sources/Hootty/Views/TerminalPaneView.swift` title-change closure to use `AgentTitleDetection.stripPrefix(_:)` and `pane.agentSessionID`. Remove the direct Claude-specific references.
- [x] 4.5 Update `Sources/Hootty/HoottyApp.swift` `onClaudeSessionDetected` (or equivalent callback that assigns to `claudeSessionID`) to write to `agentSessionID` instead. Consider renaming the closure to `onAgentSessionDetected`.

## 5. Tests — detection and model

- [x] 5.1 Update or relocate `Tests/HoottyCoreTests/ClaudeTitleParserTests.swift` for the new module path and `AgentPresence` return type. All existing assertions MUST continue to pass.
- [x] 5.2 Add `Tests/HoottyCoreTests/GeminiTitleParserTests.swift` covering each glyph (`◇✦⏲✋`), non-matching titles, `stripPrefix` with trailing 80-char padding, and edge cases (empty title, title with only the glyph).
- [x] 5.3 Add `Tests/HoottyCoreTests/CodexTitleParserTests.swift` covering Braille detection, non-Braille titles (returning nil), and confirming Codex does NOT match `✳`/`*`.
- [x] 5.4 Add `Tests/HoottyCoreTests/AgentTitleDetectionTests.swift` covering detector ordering (first-match-wins for Braille collision), `stripPrefix` fan-out, and nil-on-no-match.
- [x] 5.5 In `Tests/HoottyCoreTests/PaneEventHandlerTests.swift`, add tests for: Gemini `✋` needsAttention focus gating (fires when unfocused, no-op when focused), Codex implicit-idle transition (thinking → no prefix → `.done` when unfocused), and auto session marker persistence across unmatched titles.
- [x] 5.6 In `Tests/HoottyCoreTests/IntegrationTests.swift`, add a persist/restore test that loads a workspace fixture containing the legacy `"claudeSessionID"` key and asserts it decodes into `Pane.agentSessionID`.

## 6. Gemini wrapper script (Phase 2)

- [x] 6.1 Create `Sources/Hootty/Resources/bin/gemini` (bash script, executable bit set, chmod `755`). Script MUST pass through to the real `gemini` binary when `HOOTTY_PANE_ID` is unset. Use the existing `find_real_claude`-style pattern, renamed to `find_real_gemini`.
- [x] 6.2 Implement settings-file generation: write `${XDG_CACHE_HOME:-$HOME/Library/Caches}/hootty/gemini-settings.json` with JSON containing `SessionStart` and `CwdChanged` hooks referencing the sibling hook scripts by absolute path.
- [x] 6.3 Set `GEMINI_CLI_SYSTEM_SETTINGS_PATH=<settings-file>` in the environment before `exec`-ing the real `gemini` binary.
- [x] 6.4 Create `Sources/Hootty/Resources/bin/gemini-session-hook` that writes `\e]9;hootty:session:<HOOTTY_PANE_ID>\a` to `/dev/tty`. Nothing to stdout.
- [x] 6.5 Create `Sources/Hootty/Resources/bin/gemini-cwd-hook` that reads the cwd from the hook's stdin JSON payload (key path per Gemini docs) and writes `\e]7;file://<host><path>\a` to `/dev/tty`.
- [x] 6.6 Add the three new files to `Package.swift` resources for the `Hootty` target. *(No changes needed — `Package.swift` uses `.copy("Resources/bin")` to ship the entire directory.)*
- [ ] 6.7 Verify the wrapper resolves correctly: `make run`, open a pane, run `which gemini`, confirm it points to the bundle's `bin/gemini`. *(Manual smoke test, deferred to verification group.)*

## 7. Codex wrapper script (Phase 3)

- [ ] 7.1 Create `Sources/Hootty/Resources/bin/codex` (bash script, executable, `755`). Pass through to the real `codex` binary when `HOOTTY_PANE_ID` is unset. Locate the real binary via `find_real_codex` (iterate `PATH`, skip wrapper dir).
- [ ] 7.2 Compute `HOOTTY_CODEX_HOME="${XDG_CACHE_HOME:-$HOME/Library/Caches}/hootty/codex-home"` and ensure it exists (`mkdir -p`, `chmod 700`).
- [ ] 7.3 Rebuild the symlink overlay: clear existing symlinks in `HOOTTY_CODEX_HOME`, then for each entry in `~/.codex/` other than `config.toml` and `hooks.json`, create a symlink at `${HOOTTY_CODEX_HOME}/<entry>` pointing to the user's file.
- [ ] 7.4 Spike TOML merge strategy: try `/usr/bin/python3 -c "import tomllib, json; ..."` to read the user's `config.toml`, fall back to a hand-rolled merge if `tomllib` is absent. Decide on the final strategy and document in a comment in `bin/codex`.
- [ ] 7.5 Implement the `config.toml` merge: read user file (if any), force `features.codex_hooks = true`, write to `${HOOTTY_CODEX_HOME}/config.toml`. Preserve all other user keys.
- [ ] 7.6 Implement the `hooks.json` merge: read user file (if any), merge Hootty's `SessionStart` entry (invoking `codex-session-hook`) and `PostToolUse` entry (matcher for bash/shell, invoking `codex-cwd-hook`). User-defined hooks MUST be preserved.
- [ ] 7.7 Set `CODEX_HOME="${HOOTTY_CODEX_HOME}"` in the environment and `exec` the real `codex` binary.
- [ ] 7.8 Create `Sources/Hootty/Resources/bin/codex-session-hook` that writes `\e]9;hootty:session:<HOOTTY_PANE_ID>\a` to `/dev/tty`.
- [ ] 7.9 Create `Sources/Hootty/Resources/bin/codex-cwd-hook` that reads the cwd from the hook's stdin JSON payload and writes `\e]7;file://<host><path>\a` to `/dev/tty`.
- [ ] 7.10 Add the four new files to `Package.swift` resources for the `Hootty` target.
- [ ] 7.11 Verify the wrapper resolves correctly: `make run`, run `which codex` in a pane, confirm it points to the bundle's `bin/codex`. Also verify `~/.codex/` is untouched after the wrapper runs.

## 8. Documentation updates

- [ ] 8.1 Rewrite `docs/HOOKS.md` as `docs/AGENTS.md` (or keep the name and re-title): cover multi-agent detection, the three wrapper scripts, the `CODEX_HOME` isolation strategy, and the documented limitation (no Codex approval-prompt attention).
- [ ] 8.2 Update the Architecture tree in `CLAUDE.md` to mention `Sources/HoottyCore/Agents/`, the renamed `agentSessionID` field, and the new `Gemini`/`Codex` wrappers in `Sources/Hootty/Resources/bin/`.
- [ ] 8.3 Update `.claude/rules/coding/ghostty.md` if any new ghostty-specific patterns are discovered during wrapper implementation (probably not, since we reuse the existing OSC 9 / 7 routing).

## 9. Verification

- [ ] 9.1 `make build` succeeds.
- [ ] 9.2 `swift test` passes (ignore the signal-10 XCTest runner exit).
- [ ] 9.3 `make format-check` passes.
- [ ] 9.4 `make lint` passes.
- [ ] 9.5 Manual smoke test — Claude Code: open a Claude session in one pane, focus another, trigger a long task, verify the thinking spinner animates in the sidebar and `.done` fires when it finishes (unfocused).
- [ ] 9.6 Manual smoke test — Gemini CLI: run `gemini` in a pane, verify `which gemini` points at the bundle wrapper, verify thinking state lights up, verify `✋` fires `.done` attention when unfocused.
- [ ] 9.7 Manual smoke test — Codex CLI: run `codex` in a pane, verify `which codex` points at the bundle wrapper, verify thinking state lights up via Braille detection, verify `~/.codex/` is unchanged after running, verify `$CODEX_HOME` is set to the Hootty-managed directory inside the running process (inspect via `env` in a Codex shell tool call).
