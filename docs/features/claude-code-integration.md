# Claude Code Integration

Hootty integrates with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) out of the box. When you run `claude` inside a Hootty terminal, attention indicators and session tracking are automatically enabled with zero configuration.

## How It Works

Hootty bundles a wrapper script that transparently intercepts the `claude` command. The wrapper injects Claude Code hooks that send signals back to Hootty via terminal escape sequences. You don't need to modify your Claude Code configuration.

### Hook types

| Hook | Signal | Effect |
|------|--------|--------|
| **Stop** | Idle attention | Fires when Claude finishes a response. Hootty shows a green attention indicator. |
| **Notification** | Input attention | Fires when Claude needs permission approval or asks a question. Hootty shows a yellow attention indicator. |
| **SessionStart** | Session tracking | Fires when a Claude session begins. Hootty stores the session ID for resume capability. |

### Signal path

1. Claude Code fires a hook, which runs a `printf` command that emits an OSC 9 escape sequence.
2. Ghostty (the terminal engine) receives the escape sequence and triggers a desktop notification action.
3. Hootty parses the notification payload and routes it to the correct pane.
4. The pane's attention state or session ID is updated, and the UI reacts.

## Resuming a Claude Session

If a pane has an active Claude session, you can resume it in a new tab:

1. **Right-click** the tab in the tab bar.
2. Choose **Resume Claude Session** from the context menu.
3. A new tab opens in the same group and automatically runs `claude --resume <session-id>`.

This is useful for continuing a conversation after closing a tab or when you want a fresh terminal but the same Claude context.

## Environment Variables

Hootty sets the following environment variables in every terminal pane:

| Variable | Value | Purpose |
|----------|-------|---------|
| `HOOTTY_PANE_ID` | Pane UUID | Identifies the pane for hook signals. The wrapper script uses this to detect it's running inside Hootty. |
| `PATH` | Prepended with Hootty's `bin/` directory | Ensures the bundled `claude` wrapper is found before the system-installed `claude` binary. |

## Details

- The wrapper passes through all arguments to the real `claude` binary — it only adds `--settings` with hook configuration.
- Subcommands that don't support hooks (`mcp`, `config`, `api-key`) are passed through without modification.
- Session IDs are persisted across app restarts, so the "Resume Claude Session" option remains available after relaunching Hootty.
- If you're not using Claude Code, the wrapper has no effect — it simply detects that `claude` isn't installed and does nothing.
