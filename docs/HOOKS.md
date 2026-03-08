# Claude Code Hook Integration

Hootty automatically injects Claude Code hooks so that turn completion and permission prompts trigger attention indicators (animated borders, bell icons) — zero user configuration required.

## How It Works

```
User types `claude` in a Hootty pane
  → Shell's PATH resolves to Hootty's bundled wrapper script (prepended at surface creation)
  → Wrapper detects HOOTTY_PANE_ID env var → confirms it's running inside Hootty
  → Injects --settings with hook JSON that emits OSC 9 on Stop / permission_prompt
  → Claude Code runs normally with the extra hooks merged into settings
  → Hook fires: printf '\e]9;Claude Code needs attention\a'
  → ghostty parses OSC 9 → GHOSTTY_ACTION_DESKTOP_NOTIFICATION callback
  → GhosttyApp.signalAttention() → onPaneNeedsAttention(paneID)
  → Pane.needsAttention = true → animated border + bell icon in tab bar / sidebar
```

Outside Hootty (no `HOOTTY_PANE_ID`), the wrapper passes through to the real `claude` binary unchanged.

## Components

### 1. Wrapper Script (`Sources/Hootty/Resources/bin/claude`)

Bundled as an SPM resource via `Package.swift`. A bash script that:

- Searches `PATH` (excluding its own directory) to find the real `claude` binary
- If `HOOTTY_PANE_ID` is unset, passes through with `exec` — no overhead
- Passes through subcommands that don't support `--settings` (`mcp`, `config`, `api-key`)
- Injects `--settings` with inline JSON containing Stop, Notification, and SessionStart hooks

The `--settings` flag merges additively with the user's `~/.claude/settings.json`, so existing user hooks are preserved.

### 2. Environment Variable Injection (`TerminalSurfaceView.swift`)

When creating a ghostty surface, `applyHoottyEnvVars()` sets two env vars via `ghostty_surface_config_s.env_vars`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `HOOTTY_PANE_ID` | Pane's UUID | Lets the wrapper script detect it's inside Hootty |
| `PATH` | `<bundle-bin-dir>:$PATH` | Prepends the resource bundle's `bin/` so our `claude` wrapper is found first |

The bundle path is resolved once via `HoottyBundle.resourceBundle` (shared with icon loading).

### 3. Attention Signal Path (`GhosttyApp.swift`)

ghostty handles OSC 9 (`\e]9;...\a`) internally and fires `GHOSTTY_ACTION_DESKTOP_NOTIFICATION`. Hootty's action callback routes this to `signalAttention()`:

```
GHOSTTY_ACTION_DESKTOP_NOTIFICATION
  → GhosttyApp.signalAttention(target:)
  → extracts paneID from SurfaceCallbackContext
  → onPaneNeedsAttention?(paneID)
  → AppModel.handlePaneNeedsAttention(_:)
  → Pane.needsAttention = true
```

SwiftUI observes `needsAttention` and renders the animated border on the pane view, plus a bell icon in the tab bar and sidebar. Focusing the pane clears the flag.

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

The unfocused pane should show an animated yellow border and bell icon. Clicking its tab clears the indicator.

### Test with Claude Code

If Claude Code is installed, run `claude` in a pane, switch to another pane, and trigger a task. The original pane should signal attention immediately when Claude's turn finishes (green indicator). Permission prompts should show a yellow indicator.
