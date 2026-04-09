## Context

Hootty currently detects Claude Code sessions via two parallel channels:

1. **Hook-based session marker** — `Sources/Hootty/Resources/bin/claude` wraps the real `claude` binary and injects a `SessionStart` hook that emits `\e]9;hootty:session:<uuid>\a`. Ghostty routes the OSC 9 sequence through `GHOSTTY_ACTION_DESKTOP_NOTIFICATION` → `GhosttyApp.handleDesktopNotification` → `onClaudeSessionDetected(paneID, sessionID)` → `Pane.claudeSessionID = sessionID`.
2. **Title-based state detection** — `ClaudeTitleParser` inspects the first Unicode scalar of every title change. Braille (U+2800–28FF) → thinking, `✳`/`*` → idle. `PaneEventHandler.handleTitleChange` also auto-sets `claudeSessionID = "auto"` when a Claude-shaped title arrives without a prior hook-based marker.

The model side is already tool-agnostic — `Pane.isThinking`, `Pane.attentionKind = .done`, and `SidebarFilter.thinking` don't mention Claude. The coupling lives in three places: the parser (`ClaudeTitleParser`), the persisted field (`Pane.claudeSessionID`), and a handful of UI sites (`StatusDotView.isClaudeSession`, `AttentionKind.done.displayName = "Claude Done"`).

We want to add Gemini CLI and OpenAI Codex CLI as recognized agents with the same attention-state coverage. Investigation findings:

- **Gemini CLI** writes titles with four distinct static glyphs (`◇` idle, `✦` / `⏲` thinking, `✋` needs-attention), 80-char padded. It has a `SessionStart` hook system configured via `.gemini/settings.json`, merged across project/user/system tiers. There is no `--settings` CLI flag; the system tier can be overridden via `GEMINI_CLI_SYSTEM_SETTINGS_PATH` env var. Hook stdout is consumed by the hook subsystem, so OSC sequences MUST go to `/dev/tty`.
- **OpenAI Codex CLI** writes titles with a Braille spinner prefix during thinking, and collapses to the plain project name when idle (no idle glyph). It has a hook system equivalent to Claude's (`SessionStart`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`) but gated behind a `features.codex_hooks` flag that is off by default. Config lives in `$CODEX_HOME/config.toml` + `$CODEX_HOME/hooks.json`, with `CODEX_HOME` overridable via env var.

## Goals / Non-Goals

**Goals:**
- Generalize title-based detection into a pluggable protocol so adding a fourth agent is one file + one registry entry.
- Introduce a new `AgentPresence.needsAttention` state that lets agents explicitly request user attention (vs. Hootty inferring it from focus transitions).
- Support Gemini CLI's full attention-state set (thinking/idle/needsAttention) via title watching + a wrapper script for session marker and cwd tracking.
- Support OpenAI Codex CLI's thinking/idle transitions via title watching + a wrapper script for session marker and cwd tracking, using a `CODEX_HOME` isolation strategy that never mutates user files.
- Rename `Pane.claudeSessionID` to `Pane.agentSessionID` with a Codable fallback so existing workspace files decode without user intervention.
- Keep the UI tool-agnostic — no per-agent colors, icons, or badges.

**Non-Goals:**
- Distinguishing which agent is running in a given pane (intentional — `Pane.agentKind` is NOT added).
- Delivering `needsAttention` for Codex approval prompts (Codex's hook lifecycle has no approval-specific event; documented limitation).
- Resume support for Gemini or Codex sessions beyond a placeholder `"auto"` session marker (Claude's resume support via hook-emitted session UUID is preserved as-is).
- Theming, iconography, or labeling differences per agent.
- Changing the Ghostty-side OSC 9 routing — all agents reuse the existing `hootty:session:<id>` prefix handled by `GhosttyApp.handleDesktopNotification`.

## Decisions

### 1. Pluggable detector protocol instead of a monolithic parser

```swift
public protocol AgentTitleDetector {
    static func detect(_ title: String) -> AgentPresence?
    static func stripPrefix(_ title: String) -> String?
}

public enum AgentTitleDetection {
    static let detectors: [any AgentTitleDetector.Type] = [
        GeminiTitleParser.self,
        ClaudeTitleParser.self,
        CodexTitleParser.self,
    ]
    public static func detect(_ title: String) -> AgentPresence? { ... }
    public static func stripPrefix(_ title: String) -> String? { ... }
}
```

**Rationale:** Adding a fourth agent becomes mechanical — one new file conforming to the protocol, one registry entry. No touch to `PaneEventHandler`, `Pane`, or any UI site.

**Alternatives considered:**
- **Monolithic rule table** (single file, array of `(predicate, presence)`): tighter code but couples unrelated agent rules and makes per-agent `stripPrefix` awkward because each agent trims different numbers of characters and handles trailing padding differently.
- **Protocol with an instance-level detector registry** (no static methods): enables per-registry state but we don't need any — all detection is pure.

### 2. `AgentPresence` has three cases, not two

```swift
public enum AgentPresence: Equatable {
    case thinking
    case idle
    case needsAttention
}
```

**Rationale:** Claude and Codex only produce `.thinking` / `.idle`. Gemini produces all three via the distinct `✋` glyph. Collapsing `✋` into `.idle` (and relying on the existing "transition from thinking → idle while unfocused" rule) would lose the explicit-attention signal — Gemini's `✋` can appear without a preceding thinking state, and the agent is explicitly asserting attention regardless of what came before.

**Alternatives considered:**
- **Two cases, map `✋` to `.idle` + `.done` attention kind inside the detector**: requires the detector to know about `AttentionKind`, which couples the detection layer to the event-handling layer. Also loses the "explicitly requested" signal distinction from "inferred from focus transition."

### 3. `Pane.agentKind` is NOT persisted

**Rationale:** The UI is tool-agnostic (user's explicit design principle). The only consumers of "which agent" would be logs, telemetry, and speculative future UI. Claude and Codex also both use Braille prefixes, so the detector registry can't reliably distinguish them from title alone anyway. Storing the kind would be a field that is frequently unknown or wrong.

**Alternatives considered:**
- **Store `agentKind: AgentKind?` alongside `agentSessionID`**: dead weight in the model, Codable migration cost, no current consumer, and ambiguous for Claude/Codex overlap.

### 4. Claude field is renamed `claudeSessionID` → `agentSessionID` with Codable fallback

```swift
public convenience init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let agentSession = try c.decodeIfPresent(String.self, forKey: .agentSessionID)
        ?? c.decodeIfPresent(String.self, forKey: .claudeSessionID)
    try self.init(..., agentSessionID: agentSession, ...)
}
```

**Rationale:** One-shot rename is cheaper than carrying two fields. Codable fallback handles older workspace files transparently. Encoding only writes the new key, so re-saves migrate the file on first write.

**Alternatives considered:**
- **Keep the old name `claudeSessionID` and document it as "any agent"**: ugly and confusing for future contributors.
- **Add `agentSessionID` alongside `claudeSessionID` with a mirror**: doubles the model surface permanently for no benefit.

### 5. Implicit-idle branch in `handleTitleChange`

```swift
if let state = AgentTitleDetection.detect(title) {
    pane.agentSessionID = pane.agentSessionID ?? "auto"
    apply(state, ...)
} else if pane.agentSessionID == "auto" && pane.isThinking {
    // Title no longer matches, pane was thinking → implicit idle (Codex case)
    endThinking(workspace, pane)
}
```

**Rationale:** Codex has no idle glyph — when it finishes thinking, its title collapses from `⠋ my-project` to `my-project`. The existing Claude-specific behavior of clearing `claudeSessionID = "auto"` on unmatched titles would prematurely drop the session marker for Codex and never fire `.done` attention. The new branch treats an unmatched title on a thinking auto-session as a transition to idle while keeping the session alive until process exit.

**Trade-offs:**
- A pane that matches any agent rule once keeps its auto session marker until `processDidExit` fires. Minor stickiness — visible only if a user runs a Braille-prefixed title (e.g. from `ls` output) and then expects the marker to clear automatically without closing the pane.
- The `auto` marker is not cleared on subsequent non-agent titles, which is a deliberate divergence from the current Claude-only behavior.

**Alternatives considered:**
- **Clear the marker after N seconds of no matching title**: timer-based, fragile, adds complexity.
- **Require hook-based session markers for Codex** (no auto mode): breaks the "useful without a wrapper" fallback that works today for Claude.

### 6. `needsAttention` only fires attention when the pane is unfocused

`PaneEventHandler` applies `needsAttention` via the existing `handlePaneNeedsAttention` path, which already checks focus before setting `attentionKind`. Rationale: Gemini's `✋` is visible in the title bar (the user watching the pane already sees it); firing attention regardless of focus would double-notify.

### 7. Codex wrapper uses `CODEX_HOME` isolation with symlinks and a CLI-flag feature override

The wrapper:
1. Computes `HOOTTY_CODEX_HOME = ${XDG_CACHE_HOME:-$HOME/Library/Caches}/hootty/codex-home/`.
2. Creates it with mode `0700` if missing.
3. Clears stale symlinks.
4. Recreates symlinks for every entry in `~/.codex/` **except** `hooks.json`. Notably, `config.toml` IS symlinked — user settings are picked up live with no merge step.
5. Parses the user's `~/.codex/hooks.json` (if present), merges in Hootty's `SessionStart` + `PostToolUse` entries using Python's stdlib `json` module, writes the result to `${HOOTTY_CODEX_HOME}/hooks.json`.
6. Sets `CODEX_HOME=${HOOTTY_CODEX_HOME}` and execs the real `codex` binary with `-c features.codex_hooks=true` prepended to the args so the feature flag is enabled without touching `config.toml`.

**Rationale:** Zero mutation of user files — clean uninstall, no clobber risk, no orphaned settings, no git-dirty `~/.codex/` after running Hootty. The original plan merged `config.toml` to inject `features.codex_hooks = true`, but the `-c` CLI override offers the same effect without the merge complexity. Writing TOML portably from the default macOS Python (3.9, no `tomllib`) would require either a vendored dependency or a hand-rolled serializer — both avoidable when a CLI flag does the job.

**Alternatives considered:**
- **Mutate `~/.codex/config.toml` in place**: invasive, requires idempotent merge + un-merge logic, leaves orphans on uninstall, causes user git diffs.
- **Write a single `config.toml`/`hooks.json` into a fresh `CODEX_HOME` and lose user's other files (MCP servers, API keys, model choice)**: breaks everything the user configured.
- **Parse and re-emit `config.toml` with `tomllib` + a hand-rolled writer**: `tomllib` is stdlib from Python 3.11 only; macOS 14 ships 3.9. Requires either a vendored `tomli_w` package or a fragile custom TOML emitter. Superseded by the `-c` flag approach.

**Hooks merge implementation:** `/usr/bin/python3` with stdlib `json`. No version concerns (json is stdlib since forever). The merge preserves user-defined hooks and adds ours via `setdefault` + dedup on `command` string.

### 8. Gemini wrapper uses `GEMINI_CLI_SYSTEM_SETTINGS_PATH` with a fresh settings file per run

The wrapper:
1. Computes a settings-file path: `${XDG_CACHE_HOME:-$HOME/Library/Caches}/hootty/gemini-settings.json`.
2. Writes a fresh JSON file containing `SessionStart` and `CwdChanged` hooks.
3. Sets `GEMINI_CLI_SYSTEM_SETTINGS_PATH=<path>` and execs the real `gemini` binary.

**Rationale:** Gemini's hook merging is additive across project/user/system tiers, so Hootty's system-tier hooks run alongside any user hooks in `~/.gemini/settings.json`. We don't need a merge step — just write a fresh file containing only our hooks.

**Alternatives considered:**
- **Write to `~/.gemini/settings.json` directly**: mutates user file, same problems as Codex's Option A.
- **Project-local `.gemini/settings.json`**: dirties the user's cwd with files they didn't ask for; visible in git.

### 9. Hook stdout goes to `/dev/tty`

Both Gemini and Codex consume hook stdout as a structured response channel (JSON). OSC sequences MUST be written directly to `/dev/tty` to reach the actual terminal:

```bash
printf '\e]9;hootty:session:%s\a' "$HOOTTY_PANE_ID" > /dev/tty
```

This is a hard requirement for Phase 2+3, documented inline in each hook script.

### 10. Detector registration order

```swift
[GeminiTitleParser.self, ClaudeTitleParser.self, CodexTitleParser.self]
```

**Rationale:** Gemini's glyphs (`◇✦⏲✋`) are distinct and fastest to reject. Claude handles both Braille and `✳`/`*`. Codex is last because its Braille rule duplicates Claude's (no new result — but listed for discoverability).

## Risks / Trade-offs

- **Braille collision between Claude and Codex** → Detector registry returns the first match (currently Claude's). Since both produce `.thinking`, user-visible behavior is identical. Codex's dedicated parser is retained for discoverability but is functionally equivalent for now.
- **Codex "stuck auto marker"** → A pane that tripped an agent detector once keeps `agentSessionID = "auto"` until `processDidExit`. Edge case: a user pastes a Braille-prefixed string into a plain shell and the pane gets marked as an agent session indefinitely. Accepted; closing the pane clears it, and the user-visible effect is a small indicator that can be manually cleared by restarting the pane.
- **Codex approval-prompt attention gap** → No upstream event exists at the approval point. Documented as a known limitation in the wrapper spec. Potential future fix: file a feature request with OpenAI for a `ToolApprovalRequest` event.
- **Codex `features.codex_hooks` feature flag is experimental** → Upstream could change the flag name or remove it. Mitigation: the wrapper's merge logic is concentrated in one place; flag-name changes require a one-line edit. Fallback: if the flag is removed (hooks become default-on), the wrapper still works because setting a default-on flag to `true` is a no-op.
- **TOML merge fragility** → Implementing deep-merge for TOML is nontrivial if we hand-roll it. Mitigation: prefer `/usr/bin/python3 -c "import tomllib, tomli_w; ..."` (Python 3.11+, ships with macOS 14+). If `tomli_w` is not available in the system Python (it isn't by default), fall back to a minimal hand-rolled merge for the two keys we touch. Decision deferred to the tasks phase.
- **Gemini users who disable dynamic titles** → `settings.ui.hideWindowTitle` collapses the title to `Gemini CLI (folder)`. Title watching can't distinguish states in this mode. Session detection still works via the hook-injected OSC 9 marker. Accepted degraded-mode behavior.
- **Implicit-idle false positives** → A non-agent pane with a Braille-prefixed title (e.g. a user piping `tput` tricks) gets an `auto` session. Closing the pane clears it. Very rare; accepted.

## Migration Plan

1. **Model rename migration**: `Pane`'s Codable `init(from:)` tries `agentSessionID` first, then falls back to the legacy `claudeSessionID` key. Existing workspace JSON files decode cleanly. On next save, they are rewritten with the new key. No user action required.
2. **Theme/label migration**: `AttentionKind.done.displayName` changes from `"Claude Done"` to `"Agent Done"`. No persisted data depends on this string.
3. **Rollback**: revert the branch. Workspace files written with `agentSessionID` would fail to decode against the old model, so rollback after a save-event cycle would lose session markers (but not workspace layout). Acceptable — the field only contains runtime detection state, not user-created content.

## Open Questions

- **TOML merge implementation choice** — Python oneliner vs. hand-rolled Swift helper vs. minimal shell-based sed. Deferred to tasks phase; will be decided with a quick spike.
- **Should `AgentTitleDetection.stripPrefix` return just the cleaned string, or the cleaned string plus the detector that produced it?** The current design returns `String?`. If future logging wants to know which agent stripped the prefix, we'd need to enrich the return type. Not needed for Phase 1.
- **Gemini's "static mode" fallback** — when `useDynamicTitle` is false, Gemini writes `Gemini CLI (folder)`. We could add a weak substring-match detector for this case. Deferred per earlier discovery discussion (Phase 1 skips it).
