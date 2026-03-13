# Claude Code Hook Integration

Hootty uses a lightweight wrapper script to detect Claude Code sessions. Thinking and attention states are detected via title watching (ClaudeTitleParser) — no hooks needed for those.

## How It Works

```
User types `claude` in a Hootty pane
  → Shell's PATH resolves to Hootty's bundled wrapper script (prepended at surface creation)
  → Wrapper detects HOOTTY_PANE_ID env var → confirms it's running inside Hootty
  → Injects --settings with SessionStart hook that emits OSC 9 with session ID
  → Claude Code runs normally with the extra hook merged into settings
  → Hook fires: printf '\e]9;hootty:session:<UUID>\a'
  → ghostty parses OSC 9 → GHOSTTY_ACTION_DESKTOP_NOTIFICATION callback
  → GhosttyApp routes hootty:session: prefix → onClaudeSessionDetected(paneID, sessionID)
  → Pane.claudeSessionID is set → enables title-based thinking/idle detection
```

Once the session ID is set, ClaudeTitleParser watches terminal title changes:
- Braille spinner chars → thinking state (animated indicator)
- `✳` or `*` prefix → idle state (thinking stops)

Outside Hootty (no `HOOTTY_PANE_ID`), the wrapper passes through to the real `claude` binary unchanged.

## Components

### 1. Wrapper Script (`Sources/Hootty/Resources/bin/claude`)

Bundled as an SPM resource via `Package.swift`. A bash script that:

- Searches `PATH` (excluding its own directory) to find the real `claude` binary
- If `HOOTTY_PANE_ID` is unset, passes through with `exec` — no overhead
- Passes through subcommands that don't support `--settings` (`mcp`, `config`, `api-key`)
- Injects `--settings` with inline JSON containing a `SessionStart` hook

The `--settings` flag merges additively with the user's `~/.claude/settings.json`, so existing user hooks are preserved.

### 2. Environment Variable Injection (`TerminalSurfaceView.swift`)

When creating a ghostty surface, `applyHoottyEnvVars()` sets two env vars via `ghostty_surface_config_s.env_vars`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `HOOTTY_PANE_ID` | Pane's UUID | Lets the wrapper script detect it's inside Hootty |
| `PATH` | `<bundle-bin-dir>:$PATH` | Prepends the resource bundle's `bin/` so our `claude` wrapper is found first |

The bundle path is resolved once via `HoottyBundle.resourceBundle` (shared with icon loading).

### 3. Session Detection Path (`GhosttyApp.swift`)

ghostty handles OSC 9 (`\e]9;...\a`) internally and fires `GHOSTTY_ACTION_DESKTOP_NOTIFICATION`. Hootty's action callback routes `hootty:session:` prefixed messages:

```
GHOSTTY_ACTION_DESKTOP_NOTIFICATION
  → GhosttyApp.handleDesktopNotification(target:v:)
  → if body starts with "hootty:session:" → extract UUID
  → onClaudeSessionDetected?(paneID, sessionID)
  → Pane.claudeSessionID = sessionID
```

Any other OSC 9 notification (non-hootty prefix) is treated as a generic bell attention signal.

### 4. Title-Based State Detection (`ClaudeTitleParser` + `AppModel.handleTitleChange`)

Once `Pane.claudeSessionID` is set, title changes are parsed for Claude Code state:

| Title pattern | Detected state | Effect |
|--------------|---------------|--------|
| Braille spinner char (`⠋⠙⠹...`) | `.thinking` | `pane.isThinking = true`, clears attention |
| `✳` (U+2733) or `*` prefix | `.idle` | `pane.isThinking = false` |

## Testing

### Verify env vars are injected

In any Hootty terminal pane:

```bash
echo $HOOTTY_PANE_ID    # Should print a UUID
echo $PATH | tr ':' '\n' | head -3   # First entry should be the bundle's bin/ dir
```

### Verify the wrapper resolves

```bash
which claude   # Should point to the bundle's bin/claude (if claude is installed)
```

### Trigger attention manually

Open two panes. Focus one, then run this in the **unfocused** pane:

```bash
printf '\e]9;test notification\a'
```

The unfocused pane should show a bell icon and glow border. Clicking its tab clears the indicator.

### Test with Claude Code

If Claude Code is installed, run `claude` in a pane, switch to another pane, and trigger a task. The spinner in the terminal title should trigger the thinking indicator (animated arrow). When Claude finishes, the thinking indicator stops.

## Kitty Keyboard Protocol Reset

When a program enables the [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) (`CSI > flags u`) and then crashes or is killed without disabling it (`CSI < u`), the terminal's VT parser retains the mode. Subsequent shell input gets encoded as CSI u sequences, making the terminal unusable.

Hootty automatically resets stale keyboard modes for **bash** via the `PROMPT_COMMAND` environment variable. At each prompt, `printf '\e[<9u'` pops up to 9 entries from the keyboard mode stack (safe on an empty stack).

For **zsh**, add to `~/.zshrc`:

```zsh
[[ -n "$HOOTTY_PANE_ID" ]] && precmd_functions+=(_hootty_kitty_reset)
_hootty_kitty_reset() { printf '\e[<9u' }
```

For **fish**, add to `~/.config/fish/config.fish`:

```fish
if set -q HOOTTY_PANE_ID
    function _hootty_kitty_reset --on-event fish_prompt
        printf '\e[<9u'
    end
end
```
