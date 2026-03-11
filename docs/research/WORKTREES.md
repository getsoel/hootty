# Research: How Terminals & Custom Apps Handle Git Worktrees for Claude Code

## Landscape Overview

Git worktrees have become the standard isolation primitive for parallel AI agent workflows. The ecosystem has converged on a common pattern: **one task = one worktree = one terminal session**. Here's how each tool approaches it.

---

## Claude Code Native Worktree Support

**CLI** (v2.1.49, Feb 2026):
- `claude --worktree feature-name` creates `.claude/worktrees/feature-name/` with branch `worktree-feature-name`
- `--tmux` flag launches agent in one tmux pane + shell in another, both scoped to the worktree
- Auto-cleanup: worktrees with no changes are removed on session end; changed ones prompt keep/remove
- Sub-agents can get `isolation: worktree` in custom agent frontmatter

**Desktop App**:
- Auto-creates a worktree for every new session by default (configurable)
- Customizable worktree storage path and branch prefix
- Worktree toggle in the prompt input UI alongside model selection and permission mode

---

## Terminal-Native Apps (most relevant to Hootty)

### Ghostree (sidequery/ghostree)
- **What**: Fork of Ghostty with worktree management built into the terminal itself
- **Architecture**: Zig core (76%) + Swift macOS UI (16%), same as Ghostty. Standalone binary, no separate Ghostty install needed
- **Terminal model**: One Ghostty window per worktree, branch-aware tab labels
- **Features**: Fuzzy-find worktree switcher, inline diff viewer, per-worktree config overrides (themes/fonts/keybindings layered on top of base Ghostty config)
- **Agent notifications**: Native macOS notifications when coding agents (Claude Code, Codex, Cursor) finish in any worktree
- **Creation**: Single command to create worktree + open in new window
- **Install**: `brew install sidequery/tap/ghostree`

### Agentastic.dev
- **What**: Native macOS IDE (Swift/SwiftUI, macOS 14+) built around worktree-per-agent paradigm
- **Terminal**: Dual backend — Ghostty (primary) or SwiftTerm (fallback)
- **Worktree model**: Each "workspace" is a git worktree. Agents launched within their own worktree terminal
- **Agent support**: Any CLI agent (Claude Code, Codex, Gemini, Droid, Amp, OpenCode)
- **Code review**: Built-in diff viewer + agentic review via Claude/Codex/CodeRabbit
- **Setup hooks**: `.agentastic/setup.sh` runs during worktree creation
- **v0.6.0**, macOS 14+

### Superset (superset-sh/superset)
- **What**: Open-source macOS terminal for 10+ parallel agents
- **Architecture**: Native macOS app, Apache 2.0 license, zero telemetry
- **Worktree model**: Each agent gets its own git worktree automatically
- **Features**: Built-in diff viewer, agent monitoring dashboard, notifications when agents need attention
- **Agent agnostic**: Claude Code, OpenCode, Codex, Cursor Agent, Gemini CLI, Copilot
- **Rapid iteration**: v0.0.68 as of Feb 2026

### Kanban Code (langwatch/kanban-code)
- **What**: Kanban-board UI for orchestrating parallel Claude Code sessions
- **Architecture**: macOS (SwiftUI + SwiftTerm) and Windows (Tauri 2 + React)
- **Worktree model**: Each task card auto-creates a worktree. Tracks orphaned worktrees with cleanup workflows
- **Terminal**: Tmux sessions managed per card, with embedded SwiftTerm terminal. Users can also attach from external terminals
- **State**: Unidirectional data flow (Reducer pattern). Single `AppState` struct, side effects handled by `EffectHandler`
- **Notifications**: Claude Code hooks fire on session stop → card moves to "Waiting" → Pushover or native macOS notifications (deduped within 62s)
- **Monitoring**: Activity detection via Claude Code hooks (session stop, user prompts, lifecycle changes)
- **Remote**: SSH + Mutagen bidirectional file sync, transparent path translation
- **Search**: BM25 full-text search across all session histories
- **Session ops**: Fork sessions (parallel conversations with shared context), checkpoint at any conversation point

### Conductor (conductor.build)
- **What**: macOS app for orchestrating Claude Code + Codex agents
- **Worktree model**: Isolated workspaces per agent
- **Features**: Linear/GitHub issue injection as context, built-in diff viewer, PR creation from within app
- **MCP integration**, slash commands for agents

---

## CLI/Shell Tools (non-terminal-native)

### Git Worktree Runner (coderabbitai/git-worktree-runner)
- Bash CLI wrapping `git worktree` with editor + AI tool integration
- Auto-detects terminal emulator (tmux everywhere, Kitty/Ghostty env vars, wt.exe on WSL)
- Smart file copying (env files, configs) via `gtr.copy.include` git config
- Post-creation hooks (`gtr.hook.postCreate`), shell completion (bash/zsh/fish)
- `git gtr ai <branch>` launches configured AI tool in worktree
- Interactive fzf navigator with keybindings (ctrl-e: editor, ctrl-a: AI tool, ctrl-d: delete)
- Team config via `.gtrconfig` committed to repo

### incident.io's `w` function
- Custom bash function: `w myproject feature-name claude` creates worktree + launches Claude Code
- Auto-completion, automatic branch creation with username prefix
- Organized under `~/projects/worktrees/`
- Enables 7 concurrent Claude conversations with complete isolation

---

## Common Patterns Across All Tools

| Pattern | Prevalence | Notes |
|---------|-----------|-------|
| One worktree per agent/task | Universal | The core isolation primitive |
| Auto-create worktree on task start | Most apps | Some auto-name, some prompt |
| Auto-cleanup empty worktrees | Claude Code, some apps | Remove if no changes made |
| Branch-aware UI (tab labels, sidebar) | Ghostree, Agentastic, Superset | Show which branch/worktree is active |
| Native macOS notifications on agent completion | Ghostree, Kanban Code, Superset | Detect via hooks or process monitoring |
| Built-in diff viewer | Agentastic, Kanban Code, Superset, Conductor | Review agent changes before merging |
| Per-worktree config overrides | Ghostree, gtr | Layer worktree-specific settings |
| Setup hooks on worktree creation | Agentastic (`.agentastic/setup.sh`), gtr (`postCreate`) | Install deps, set env vars |
| Embedded terminal (SwiftTerm) | Kanban Code, Agentastic (fallback) | Alternative to Ghostty/system terminal |
| Tmux as session manager | Kanban Code, Claude Code `--tmux`, incident.io | Persistent sessions, reattach |
| Agent-agnostic design | Superset, Agentastic, gtr | Support any CLI agent, not just Claude |

---

## Key Takeaways for Hootty

1. **Worktree-as-workspace is the dominant model** — each workspace maps to a git worktree with its own branch. This maps naturally to Hootty's existing Workspace concept.

2. **Agent completion detection** is the most valued feature — all native apps implement notifications when agents finish (via process exit, Claude Code hooks, or shell integration).

3. **Built-in diff review** is table-stakes for worktree-native terminals — users want to review agent changes without leaving the terminal app.

4. **Branch-aware UI** (tab labels showing branch, sidebar showing worktree status) helps users maintain context across many parallel sessions.

5. **Hootty's advantage**: Already has libghostty (Ghostree had to fork all of Ghostty), split panes, workspaces, and an attention/bell system. Adding worktree awareness would be layering on top of a strong foundation rather than building from scratch.

6. **SwiftTerm** appears as a fallback terminal in Agentastic and as the primary terminal in Kanban Code — notable since Hootty uses libghostty which is more capable.

---

## Sources

- [Ghostree](https://ghostree.app/) — [GitHub](https://github.com/sidequery/ghostree) — [HN Discussion](https://news.ycombinator.com/item?id=46758682)
- [Agentastic.dev](https://www.agentastic.dev/) — [HN Discussion](https://news.ycombinator.com/item?id=46501758)
- [Superset](https://superset.sh/) — [GitHub](https://github.com/superset-sh/superset)
- [Kanban Code](https://github.com/langwatch/kanban-code)
- [Conductor](https://docs.conductor.build/)
- [Git Worktree Runner](https://github.com/coderabbitai/git-worktree-runner)
- [incident.io blog](https://incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees)
- [Claude Code Worktree Guide](https://claudefa.st/blog/guide/development/worktree-guide)
- [Boris Cherny on worktree support](https://www.threads.com/@boris_cherny/post/DVAAnexgRUj/)
- [Claude Code Desktop worktree issue](https://github.com/anthropics/claude-code/issues/31896)
