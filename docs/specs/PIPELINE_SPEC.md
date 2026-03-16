# Pipeline — Spec (v2)

## Overview

A kanban-style pipeline system where jobs progress through ordered stages. Each stage is either **automated** (executes immediately when a job arrives) or **manual** (waits for human approval). Jobs execute sequentially in a bound terminal session.

**v2 change**: The pipeline engine is decoupled from Hootty into a standalone CLI tool + optional daemon. Any client — Hootty, Claude Code (via hooks + Bash), shell scripts, or a TUI — can interact with the same board through the CLI. No MCP server needed — any agent that can run shell commands can use the pipeline.

### Design Principles

1. **File-first** — Board state lives in human-readable files. Git-friendly, inspectable, editable by hand.
2. **CLI-driven** — All operations go through the `hootty pipeline` CLI. No special protocols — just shell commands.
3. **Daemon-optional** — Files alone are sufficient for basic use. The daemon adds real-time events and auto-execution.
4. **Agent-agnostic** — Any AI agent that can run shell commands (Claude Code, Codex, Copilot, Cursor) works out of the box.
5. **Composable** — Each layer (storage, CLI, daemon, UI) can be swapped independently.

### Terminology

| Term | Definition |
|------|-----------|
| **Pipeline** | Named sequence of stages with a pool of jobs |
| **Stage** | A step in the lifecycle (column). Either `automated` or `manual` |
| **Job** | A unit of work that progresses through stages |
| **Daemon** | Background process managing board state and real-time events |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTS                              │
│                                                             │
│  ┌──────────┐  ┌─────────────┐  ┌─────┐  ┌──────────────┐  │
│  │  Hootty  │  │ Claude Code │  │ User│  │  TUI / Web   │  │
│  │ Sidebar  │  │(hooks+Bash) │  │Shell│  │              │  │
│  └────┬─────┘  └──────┬──────┘  └──┬──┘  └──────┬───────┘  │
│       │               │            │             │          │
└───────┼───────────────┼────────────┼─────────────┼──────────┘
        │               │            │             │
        ▼               ▼            ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                   CLI (hootty pipeline)                      │
│         init · status · add · advance · move · play         │
└───────────────────────────┬─────────────────────────────────┘
                            │
              ┌─────────────┼──────────────┐
              ▼                            ▼
┌──────────────────────┐    ┌──────────────────────────────┐
│  FILE STORAGE        │    │  DAEMON (optional)           │
│  .hootty/pipeline/          │    │  Real-time events + auto-    │
│  pipeline.yaml       │◄──│  execution via Unix socket    │
│  stages/*/*.md       │    │                              │
│  .state.json         │    │  Watches files, drives       │
│                      │    │  runners, emits events       │
└──────────────────────┘    └──────────────────────────────┘
```

### Layer Responsibilities

| Layer | Role | Can work alone? |
|-------|------|-----------------|
| **File storage** | Canonical state. Human-readable, git-tracked | Yes — edit files by hand |
| **CLI** | Read/write board state, control daemon | Yes — talks to files or daemon |
| **Daemon** | Real-time events, execution engine | No — needs files |
| **Hootty sidebar** | Native macOS UI for the board | No — talks to daemon via socket |

## File Storage

### Directory Structure

A repo can have multiple pipelines. Each pipeline is a subdirectory of `.hootty/pipeline/` with its own config and stages.

```
.hootty/pipeline/
├── config.yaml                    # Repo-level config (default pipeline, shared settings)
├── memory.md                      # Shared project context (prepended in claim --format context)
├── .state.json                    # Runtime state for all pipelines (not git-tracked)
│
├── feature/                       # "feature" pipeline
│   ├── pipeline.yaml              # Pipeline config: stages, settings
│   ├── backlog/
│   │   ├── 001-auth-refactor.md
│   │   └── 002-fix-sidebar.md
│   ├── implement/
│   │   └── 003-add-tests.md
│   ├── review/
│   └── done/
│       └── 000-setup.md
│
├── bugs/                          # "bugs" pipeline
│   ├── pipeline.yaml
│   ├── triage/
│   │   └── 001-crash-on-login.md
│   ├── fix/
│   ├── verify/
│   └── done/
│
└── release/                       # "release" pipeline
    ├── pipeline.yaml
    ├── todo/
    └── done/
```

Stage directories are siblings of `pipeline.yaml` inside each pipeline folder. The directory names match the stage `name` field (lowercased, hyphenated).

**Single pipeline shorthand**: If a repo only needs one pipeline, `hootty pipeline init` creates it as `.hootty/pipeline/default/`. The CLI treats `default` as the implicit pipeline when `--pipeline` is omitted.

### config.yaml (Repo-Level)

```yaml
default: feature                   # pipeline used when --pipeline is omitted
```

### pipeline.yaml (Per-Pipeline)

```yaml
name: "Feature Pipeline"

stages:
  - name: Backlog
    type: manual
  - name: Implement
    type: automated
  - name: Review
    type: manual
  - name: Test
    type: automated
    command: "write tests for the changes you just made"
  - name: Commit
    type: automated
    command: "/commit"
  - name: Done
    type: manual

settings:
  pause_on_error: true             # auto-interrupt on failure
  max_claims: null                 # max simultaneous claimed jobs (null = unlimited)
  variables: {}                    # user-defined key-value pairs for {{var}} substitution
```

### Job Files (Markdown + YAML Frontmatter)

```markdown
---
title: Refactor auth module
priority: high
labels: [auth, refactor]
created: 2026-03-13T10:00:00Z
---

Refactor the auth module to use async/await instead of callbacks.
Focus on `Sources/Auth/LoginService.swift` and `Sources/Auth/TokenManager.swift`.

## Notes

- Keep backward compatibility with existing API
- Add error handling for network timeouts
```

The **filename** determines sort order within a stage (numeric prefix). The **directory** determines which stage a job is in — moving a file between directories moves it between stages (like vscode-agent-kanban).

**Prompt boundary**: The **original prompt** is the body between frontmatter and the first `##` heading. Everything below (`## Research`, `## Notes`, `## Log`) is accumulated context. `hootty pipeline advance` prints the stage command or original prompt. `hootty pipeline claim --format context` injects the **full file** so the next session gets complete context.

### Context Carryover

Stage commands tell Claude to write output back to the job file under a stage heading. This is convention-based — no special framework. The file grows over time as a living document.

```markdown
---
title: Refactor auth module
---

Refactor the auth module to use async/await.

## Research

- LoginService.swift uses completion handlers on lines 45-120
- TokenManager.swift has 3 callback chains
- No existing tests for auth module

## Notes

- Keep backward compat

## Log

- 2026-03-13 10:00 — Created in Backlog
- 2026-03-13 10:15 — Claimed by sess_a1b2c3
- 2026-03-13 10:15 — Advanced to Implement
```

`hootty pipeline claim --format context` reads the full file — prepends `memory.md` (if present), then includes the job file with all prior stage outputs and log. Context carries forward across sessions automatically.

### memory.md

Shared project context prepended in every `hootty pipeline claim --format context` output, before the job content. Contains project conventions, architecture notes, team norms. Edited by hand or `hootty pipeline edit memory`. Not shown on board cards — it's global, not per-job.

### Job Logs

Every `hootty pipeline claim`, `hootty pipeline advance`, `hootty pipeline release`, `hootty pipeline move`, and `hootty pipeline log` appends a timestamped entry to the `## Log` section in the job file. This provides a complete audit trail, git-tracked alongside the job content.

### .state.json (Runtime, Not Git-Tracked)

Lives at `.hootty/pipeline/.state.json`. Tracks runtime state for all pipelines in the repo.

```json
{
  "pipelines": {
    "feature": {
      "claims": {
        "sess_a1b2c3": "003-add-tests",
        "sess_d4e5f6": "001-auth-refactor"
      },
      "job_statuses": {
        "003-add-tests": "active",
        "001-auth-refactor": "active",
        "002-fix-sidebar": "queued"
      },
      "paused": false,
      "injection_target": null
    },
    "bugs": {
      "claims": {
        "sess_x7y8z9": "001-crash-on-login"
      },
      "job_statuses": {
        "001-crash-on-login": "active"
      },
      "paused": false,
      "injection_target": null
    }
  }
}
```

`claims` maps session IDs to job slugs. Multiple sessions can each claim a different job and work in parallel — within the same pipeline or across different pipelines.

This is ephemeral runtime state. If the daemon dies, `.state.json` is stale — on restart, all `active` jobs are reset to `interrupted` and claims are cleared.

`injection_target` is only used for daemon-driven auto-execution (see below). Most workflows don't need it.

## Connection Patterns

Everything goes through the CLI. No special protocols — any agent or script that can run shell commands can use the pipeline.

### Pattern 1: CLI (Primary Interface)

```bash
# Board management
hootty pipeline init                          # Create .hootty/pipeline/default/ (single pipeline)
hootty pipeline init feature --template review # Create named pipeline with template
hootty pipeline init bugs --template simple   # Create another pipeline
hootty pipeline status                        # Show default pipeline board
hootty pipeline status bugs                   # Show specific pipeline board
hootty pipeline status --all                  # Show all pipelines
hootty pipeline status --json                 # Machine-readable

# Job management (operates on default pipeline unless specified)
hootty pipeline add "Refactor auth module"    # Add to default pipeline's backlog
hootty pipeline add bugs "Login crash"        # Add to bugs pipeline's backlog
hootty pipeline add --stage implement "Fix"   # Add to specific stage
hootty pipeline move 001 review               # Move job to specific stage

# Claim & execute
hootty pipeline claim                         # Claim from default pipeline
hootty pipeline claim bugs                    # Claim from bugs pipeline
hootty pipeline claim --job 003-add-tests     # Claim a specific job by slug
hootty pipeline claim --format context        # Claim and output structured context
hootty pipeline advance                       # Advance claimed job (outputs next prompt)
hootty pipeline release                       # Release claim without advancing
hootty pipeline current-job                   # Show claimed job (without claiming a new one)

# Engine control
hootty pipeline play                          # Resume default pipeline
hootty pipeline play bugs                     # Resume specific pipeline
hootty pipeline pause                         # Pause default pipeline

# Daemon
hootty pipeline daemon start                  # Start background daemon
hootty pipeline daemon stop                   # Stop daemon
hootty pipeline daemon status                 # Check daemon state
```

**Without daemon**: CLI reads/writes `.hootty/pipeline/` files directly. No real-time events, no execution engine — purely a file manipulation tool.

**With daemon**: CLI sends commands over Unix socket. Gets real-time feedback.

### Pattern 2: Claude Code Hooks + Bash

Claude Code interacts with the pipeline through two mechanisms:
- **Hook** injects pipeline **awareness** on session start (board state, not a claim)
- **Bash tool** for on-demand interaction (claim, advance, status, add jobs)

```json
// .claude/hooks.json
{
  "hooks": {
    "session_start": [{
      "command": "hootty pipeline status --format context 2>/dev/null || true",
      "description": "Inject pipeline board awareness"
    }]
  }
}
```

On session start, the hook shows Claude the board state. Output:

```
## Pipelines in this repo

### feature (3 jobs)
- Backlog: 001-auth-refactor, 002-fix-sidebar
- Implement: 003-add-tests (active, claimed)
- Review: (empty)
- Done: 000-setup

To pick up a task: `hootty pipeline claim` or `hootty pipeline claim <job-slug>`
```

If no `.hootty/pipeline/` exists or no jobs are queued, outputs nothing. Claude does **not** auto-claim a job. The user explicitly asks Claude to pick up work:

```
User: "pick up the next pipeline task"
Claude: *runs `hootty pipeline claim --format context`*
→ claims 001-auth-refactor, sees prompt, starts working

User: "refactor the login page" (unrelated to pipeline)
Claude: *works normally, ignores pipeline context*
```

Claude interacts with the pipeline via Bash — no special integration:

```bash
hootty pipeline claim                         # Claim next available job
hootty pipeline claim --job 002-fix-sidebar   # Claim specific job
hootty pipeline advance                       # Move to next stage (outputs next prompt)
hootty pipeline status --json                 # Check board state
hootty pipeline add bugs "Found a crash"      # Add new job to a pipeline
hootty pipeline release                       # Drop current claim
```

### Pattern 3: Unix Socket (Real-time Events)

The daemon listens on a Unix socket for real-time UI updates. This is how Hootty's sidebar stays in sync.

```
.hootty/pipeline/pipeline.sock
```

**Events emitted (daemon → clients):**

```json
{"event": "job_moved", "job": "003", "from": "implement", "to": "review"}
{"event": "job_status_changed", "job": "003", "status": "interrupted"}
{"event": "pipeline_paused"}
{"event": "runner_idle"}
{"event": "error", "job": "003", "message": "Tests failed"}
```

**Commands accepted (clients → daemon):**

```json
{"command": "advance", "job": "003"}
{"command": "add_job", "title": "Fix bug", "prompt": "..."}
{"command": "pause"}
{"command": "bind_runner", "type": "hootty_pane", "id": "uuid"}
```

Hootty connects over this socket for real-time sidebar updates. Multiple clients can connect simultaneously.

### Pattern 4: File Watching (No Daemon)

For the simplest setup: no daemon, no socket. Just files.

- A client watches `.hootty/pipeline/stages/` for filesystem events
- Moving a file between directories = moving a job between stages
- Writing a new `.md` file = adding a job
- Reading `pipeline.yaml` = getting stage config

This is the **fallback mode** — always works, no infrastructure. Hootty can use `FSEvents` to watch the directory. Claude Code can just read the files. Users can `mv` files in the shell.

## Execution Engine

### Daemon Core Loop

Two paths: self-driven (CLI calls) and daemon-driven (auto-injection).

**Self-driven** (what `hootty pipeline advance` does):
```
1. Look up the job claimed by this session
   - If no claim → error: "No active claim. Run `hootty pipeline claim` first." (exit 1)
2. If pipeline.paused → error
3. Move job file to the next stage's directory
4. If next stage is `automated`:
   - Resolve prompt: stage.command ?? job body
   - Run {{variable}} substitution
   - Print prompt to stdout (caller acts on it)
   - Set job status → active, keep claim
5. If next stage is `manual`:
   - Set job status → interrupted
   - Release claim
   - Print "waiting for human"
6. If no next stage:
   - Move job file to `done/`
   - Set job status → completed
   - Release claim
   - Print "completed"
```

**Daemon-driven** (Hootty auto-execution):
```
1. Hootty pane signals idle (AttentionKind.idle)
2. If pipeline.paused → do nothing
3. If pane has an active claimed job → advance it (same as above)
4. If next stage is automated → inject prompt into pane via ghostty_surface_write()
5. If next stage is manual → trigger AttentionKind.input on pane
6. If no claimed job → auto-claim next available → inject prompt
```

### Session ↔ Task Association: The Claim Model

The pipeline lives in the repo (`.hootty/pipeline/`). A session associates with a specific job by **claiming** it — like pulling a card off a kanban board.

```bash
$ hootty pipeline claim
✓ Claimed job: 001-auth-refactor (stage: Implement)
▶ Prompt:
Refactor the auth module to use async/await...
```

**Session identity**: Each session needs a stable ID so claims survive across CLI calls within the same session. Resolution order:
1. `$PIPELINE_SESSION` env var (explicit, set by user or wrapper script)
2. `$CLAUDE_SESSION_ID` (set by Claude Code)
3. Terminal PID (`$PPID` or parent process ID)
4. Auto-generated UUID (written to `.hootty/pipeline/.sessions/<id>`)

**Claim priority order** (what `hootty pipeline claim` grabs):
1. `interrupted` jobs first (already in-flight, need attention)
2. First stage with unclaimed `queued` jobs (by filename sort order)
3. Skip jobs claimed by another live session

**Stale claim cleanup**: Every `hootty pipeline claim` and `hootty pipeline advance` checks if existing claims have live PIDs (`kill -0 $pid`). Dead PID → auto-release. For non-PID session IDs, `hootty pipeline reap` manually cleans up. `hootty pipeline claim --force <job>` overrides any claim.

**Double claim**: Error by default ("You already have a claim. Run `hootty pipeline release` first."). One claim per pipeline allowed — so you can hold claims on `feature` and `bugs` simultaneously.

**Claim lifecycle:**
1. `hootty pipeline claim` — grabs next claimable job (priority order above), records `session_id → job_slug` in `.state.json`
2. Session works on the job
3. `hootty pipeline advance` — moves the claimed job to next stage. If next stage is automated, the claim carries forward and the next prompt is printed. If manual, the claim is released and the job waits.
4. `hootty pipeline release` — explicitly unclaim without advancing (e.g., if you need to switch tasks)

**Empty claim**: If no jobs are claimable, exits with code `1`. Human output: `No jobs available to claim in pipeline "feature".` With `--format context`, outputs empty string.

**Multiple sessions, multiple jobs:**
```
Terminal 1:  hootty pipeline claim  →  gets 001-auth-refactor
Terminal 2:  hootty pipeline claim  →  gets 002-fix-sidebar  (001 is taken)
Terminal 3:  hootty pipeline claim  →  gets 003-add-tests    (001, 002 are taken)
```

Each terminal works independently. No coordination needed — the claim is the lock.

**Explicit pick** (skip the queue):
```bash
$ hootty pipeline claim --job 003-add-tests   # claim a specific job by slug
$ hootty pipeline claim --stage review        # claim from a specific stage
```

**Two execution models:**

| Model | Who drives? | How prompts flow | Daemon needed? |
|-------|------------|------------------|----------------|
| **Self-driven** | Claude (or user) calls `hootty pipeline claim` / `hootty pipeline advance` | CLI output → Claude reads it | No |
| **Injected** | Daemon detects idle → injects next prompt | Keystroke injection into terminal | Yes |

**Self-driven** (Claude Code, manual terminal work):
- Session claims a job via `hootty pipeline claim`
- Claude/user works on it
- `hootty pipeline advance` moves to next stage and outputs next prompt
- No daemon, no binding — just CLI calls

**Injected** (Hootty pane automation):
- Daemon watches for idle signal (Hootty `AttentionKind.idle`)
- Daemon auto-claims next job and injects prompt into the terminal via `ghostty_surface_write()`
- Requires explicit target: `hootty pipeline inject-target --pane <uuid>`
- Stored in `.state.json` as `injection_target`

Most workflows use self-driven. Injected mode is a Hootty-specific optimization for fully hands-off automation.

### Error Handling

When `settings.pause_on_error` is enabled:

1. Runner reports error (exit code, error pattern, explicit signal)
2. Daemon sets job status → `interrupted`
3. Emits `error` event to all clients
4. Job stays in current stage until user manually advances
5. User can inspect output, fix the issue, then `hootty pipeline advance`

## Data Model

```
Repo (directory: .hootty/pipeline/)
├── defaultPipeline: String      — from config.yaml
├── pipelines: [Pipeline]        — one per subdirectory
└── memory: String               — shared memory.md content

Pipeline (directory: .hootty/pipeline/<name>/)
├── name: String                 — directory name
├── stages: [Stage]              — ordered, from pipeline.yaml
├── paused: Bool                 — from .state.json
├── claims: [SessionID: JobSlug] — which session owns which job, from .state.json
├── injectionTarget: String?     — pane UUID for daemon-driven mode, from .state.json
└── jobs: [Job]                  — derived from <name>/<stage>/*.md files

Stage (from pipeline.yaml)
├── name: String
├── type: automated | manual
└── command: String?             — prompt override (nil = use job body)

Job (file: .hootty/pipeline/<pipeline>/<stage>/<nnn>-<slug>.md)
├── slug: String                 — derived from filename
├── title: String                — from frontmatter
├── priority: String?            — from frontmatter
├── labels: [String]             — from frontmatter
├── created: Date                — from frontmatter
├── prompt: String               — markdown body (up to ## Notes)
├── stage: String                — derived from parent directory
└── status: JobStatus            — from .state.json

JobStatus: queued | active | interrupted | completed
```

## Hootty Integration

### Pipeline Bar

A separate bar below the pane bar, only visible when the pane is connected to a pipeline. Keeps the pane bar focused on terminal identity (name, branch, actions).

```
┌──────────────────────────────────────────────────────────────────┐
│ [●] auth refactor              myrepo⎇main              [⊞] [×] │  ← pane bar (unchanged)
├──────────────────────────────────────────────────────────────────┤
│ feature › 001-auth-refactor    ○ ○ ● ○ ○ ○    Implement  [▶][×] │  ← pipeline bar (new)
│                                      ↑                          │
│                                 stage dots                      │
└──────────────────────────────────────────────────────────────────┘
│                                                                  │
│                         terminal surface                         │
│                                                                  │
```

**Visibility:**

| State | Pipeline bar |
|-------|-------------|
| No `.hootty/pipeline/` in repo | Hidden |
| `.hootty/pipeline/` exists, no claim | Hidden |
| Job claimed | Shown |
| Job released / completed | Hides (with brief fade) |

The bar only appears when this session has an active claim. No pipeline → no bar → no wasted space.

**Layout:**

```
[pipeline] › [job title]    [stage dots]    [stage name]    [actions]
```

- **Pipeline name** — which pipeline (`feature`, `bugs`)
- **Job title** — from frontmatter (`001-auth-refactor`)
- **Stage dots** — filled/empty circles showing progress through stages. Current stage is highlighted. Compact, always fits.
- **Stage name** — current stage label (`Implement`, `Review`)
- **Actions** — play/pause pipeline `[▶]`, release claim `[×]`

**Stage dot states:**

```
○ ○ ● ○ ○ ○    — active at stage 3 of 6 (Implement)
○ ○ ◉ ○ ○ ○    — interrupted at stage 3 (waiting for human)
● ● ● ● ○ ○    — completed through stage 4, active at 5
```

**Interactions:**

- **Click stage dot** → if manual stage ahead, shows tooltip with stage name. If current stage is interrupted, clicking the next dot advances.
- **Click job title** → opens the job's `.md` file in the terminal (`$EDITOR`) or shows a popover with prompt preview
- **Click pipeline name** → switches to Pipelines view, highlights this job's card
- **`[×]` button** → releases the claim (`hootty pipeline release`)
- **Hover** → tooltip shows full job title, stage name, and time in current stage

**Styling:**
- Same height as pane bar (38pt) or slightly thinner (28pt) to feel subordinate
- Uses `tokens.surface` background (one shade darker than tab bar) with `tokens.border` separator
- Stage dots use `tokens.textMuted` (empty), `tokens.textAccent` (active), `tokens.statusBell` (interrupted)

### How Hootty Detects Pipeline Connection

Hootty watches for `.hootty/pipeline/` at each pane's **canonical repo root** (`Pane.repoRoot`, resolved via `GitWorktreeManager.canonicalRepoRoot`). This works identically whether the pane is in the main repo or a worktree.

```
Terminal opens in repo (or worktree)
  └─ Hootty resolves canonicalRepoRoot → checks: does .hootty/pipeline/ exist?
     ├─ No  → nothing (no pipeline bar, no overhead)
     └─ Yes → watch .state.json with FSEvents (at canonical root)

User/Claude runs `hootty pipeline claim` in this terminal
  └─ .state.json updates with new claim (at canonical root)
  └─ Hootty matches claim to pane:
     ├─ pane.claudeSessionID matches $CLAUDE_SESSION_ID in claim
     ├─ pane's shell PID matches $PPID in claim
     └─ $PIPELINE_SESSION env var in pane's environment matches claim
  └─ Pipeline bar slides in below pane bar

User/Claude runs `hootty pipeline advance`
  └─ .state.json updates → pipeline bar updates stage dots + stage name

User/Claude runs `hootty pipeline release` or job completes
  └─ .state.json claim removed → pipeline bar fades out
```

**No daemon required for pipeline bar**: This is pure file watching. Reads `.hootty/pipeline/` files at the canonical root — no daemon or socket needed. One FSEvents watcher per canonical repo root (shared across all worktree panes for that repo).

### View Switcher

The kanban board is a separate top-level view, not crammed into the sidebar. A view switcher in the title bar area toggles between **Terminals** and **Pipelines**.

```
┌──────────────────────────────────────────────────────────────────┐
│           ● ● ●        [ Terminals | Pipelines ]                 │  ← title bar
├──────────────────────────────────────────────────────────────────┤
```

- **Terminals** — the current view (sidebar + split panes + terminal surfaces)
- **Pipelines** — full-page kanban board

The switcher is a segmented control or tab pair in the title bar, next to the traffic lights. Keyboard shortcut to toggle (e.g., `⌘1` / `⌘2` or a dedicated binding).

### Kanban Board View (Pipelines Page)

When "Pipelines" is selected, the entire content area becomes the kanban board. The sidebar is hidden or replaced with a pipeline list.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  ● ● ●           [ Terminals | ▪Pipelines ]                                     │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ┌──────────┐                                                                     │
│ │ feature ◂│  pipeline selector (dropdown or tabs if multiple pipelines)   [▶][+]│
│ └──────────┘                                                                     │
├──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬────────────────┤
│ Backlog  │Implement │ Review   │ Test     │ Commit   │ Done     │                │
│ (2)      │ (1)      │ (1)      │          │          │ (1)      │                │
│          │          │          │          │          │          │                │
│ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │          │          │ ┌──────┐ │                │
│ │003   │ │ │002 ● │ │ │001 ◉ │ │          │          │ │000   │ │                │
│ │add   │ │ │fix   │ │ │auth  │ │          │          │ │setup │ │                │
│ │tests │ │ │side- │ │ │refac-│ │          │          │ │      │ │                │
│ │      │ │ │bar   │ │ │tor   │ │          │          │ │      │ │                │
│ │ low  │ │ │      │ │ │      │ │          │          │ │      │ │                │
│ └──────┘ │ │ high │ │ │⏸ sess│ │          │          │ └──────┘ │                │
│ ┌──────┐ │ └──────┘ │ │ _a1b │ │          │          │          │                │
│ │004   │ │          │ └──────┘ │          │          │          │                │
│ │update│ │          │          │          │          │          │                │
│ │docs  │ │          │          │          │          │          │                │
│ │      │ │          │          │          │          │          │                │
│ │ low  │ │          │          │          │          │          │                │
│ └──────┘ │          │          │          │          │          │                │
│          │          │          │          │          │          │                │
│ [+ Add]  │          │          │          │          │          │                │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴────────────────┘
```

**Columns** = stages. Each column shows its stage name, job count, and type indicator (▶ automated, ⏸ manual).

**Cards** = jobs. Each card shows:
- Job number + title
- Priority label (color-coded)
- Claim indicator: `●` active (which session), `◉` interrupted
- Labels/tags

**Interactions:**

- **Drag card** between columns → `hootty pipeline move` (forward or backward)
- **Click card** → expands to show full prompt, notes, metadata. Edit inline.
- **Click `[+ Add]`** at column bottom → inline card appears → type title → Enter → stub `.md` file created (auto-numbered). Click to expand and write full prompt.
- **Double-click card title** → rename
- **Right-click card** → context menu: Edit, Claim, Advance, Move Back, Delete
- **Right-click column header** → "Add Stage After", "Remove Stage", "Change Type (auto/manual)"
- **Click `[▶]`** → play/pause pipeline
- **Click `[+]`** → create new pipeline

**Card detail (expanded):**

```
┌────────────────────────────────────────┐
│ 001-auth-refactor            ◉ Review  │
│ ──────────────────────────────────────  │
│ Refactor the auth module to use        │
│ async/await instead of callbacks.      │
│ Focus on LoginService.swift and        │
│ TokenManager.swift.                    │
│                                        │
│ Priority: high                         │
│ Labels: auth, refactor                 │
│ Claimed by: sess_a1b2c3 (Terminal 2)   │
│ Created: 2026-03-13                    │
│                                        │
│ [Advance] [Release] [Edit] [Delete]    │
└────────────────────────────────────────┘
```

**Pipeline selector**: If the repo has multiple pipelines, a dropdown or horizontal tab bar at the top lets you switch between them. Badge shows total active/interrupted jobs per pipeline.

**Repo scope**: The board shows pipelines from the focused pane's repo. A repo indicator in the header shows which repo is displayed. If panes span multiple repos with `.hootty/pipeline/` directories, a repo picker dropdown lets the user switch. Empty state with setup instructions if no pipelines exist.

### Terminals ↔ Pipelines Navigation

The two views are connected:

- **Pipeline bar → Board**: Click the pipeline name in a pane's pipeline bar → switches to Pipelines view, highlights that job's card
- **Board → Terminal**: Click a claimed card's session indicator → switches to Terminals view, focuses the pane that has the claim
- **Board → Terminal**: Right-click card → "Open in Terminal" → switches to Terminals view and runs `hootty pipeline claim <job>` in the focused pane

### Attention Integration

- Job enters manual stage → notification badge on the "Pipelines" tab in the title bar
- If a claimed job is interrupted → the pane's attention system fires as usual (bell, border glow)
- The Pipelines tab shows a dot/badge when any job needs human attention

### Injection Target (Auto-execution)

For fully hands-off automation, Hootty can set a pane as the injection target: right-click a pane → "Auto-run Pipeline" → the daemon injects prompts into that pane when jobs advance. This is the `injection_target` in `.state.json`. Only needed when you want the daemon to drive execution — Claude Code's self-driven workflow doesn't use this.

## Claude Code Integration

### Setup

```json
// .claude/hooks.json
{
  "hooks": {
    "session_start": [{
      "command": "hootty pipeline status --format context 2>/dev/null || true",
      "description": "Inject pipeline board awareness"
    }]
  }
}
```

One hook. Injects awareness, not a claim. Claude does the rest via Bash.

If no `.hootty/pipeline/` exists in the repo, the command outputs nothing and the `|| true` ensures the hook succeeds silently.

### Connection Flow

Terminals aren't associated with pipeline jobs by default. The connection is explicit:

```
1. Terminal enters a repo
   └─ Hootty detects .hootty/pipeline/ → shows muted pipeline indicator in pane bar

2. User starts Claude Code
   └─ session_start hook injects board awareness:
      "Pipeline: feature (3 jobs queued in backlog)"

3. User decides to engage (or not)
   ├─ "pick up the next task" → Claude runs `hootty pipeline claim`
   ├─ "work on the auth refactor" → Claude runs `hootty pipeline claim --job 001-auth-refactor`
   └─ "just fix this CSS bug" → Claude works normally, ignores pipeline

4. After claim:
   └─ Hootty pane bar updates: `feature › Implement 3/6`
   └─ Claude has the job prompt and pipeline instructions
```

### How Claude Knows to Advance

When Claude runs `hootty pipeline claim --format context`, it gets the job prompt AND instructions:

```
## Pipeline: feature
**Claimed job**: Refactor auth module (stage: Implement)
**Next stage**: Review (manual — will pause for human review)

### Task
Refactor the auth module to use async/await instead of callbacks.
Focus on `Sources/Auth/LoginService.swift` and `Sources/Auth/TokenManager.swift`.

### Pipeline Instructions
When you have completed this task, run: `hootty pipeline advance`
This will move the job to the next stage. If the next stage is automated,
its prompt will be printed — continue working on it. If manual, stop and
wait for the user.
```

The key mechanic: **`hootty pipeline advance` outputs the next prompt.**

```bash
$ hootty pipeline advance
✓ Job "auth-refactor" advanced: Implement → Review (manual)
⏸ Waiting for human review. Claim released.
```

```bash
$ hootty pipeline advance
✓ Job "auth-refactor" advanced: Review → Test (automated)
▶ Next prompt:
Write tests for the changes you just made.
```

```bash
$ hootty pipeline advance
✓ Job "auth-refactor" advanced: Test → Commit (automated)
▶ Next prompt:
/commit
```

Claude sees the output of `hootty pipeline advance` in its Bash tool result. If it says "Next prompt: ...", Claude continues working. If it says "Waiting for human", Claude stops. This creates a **natural loop within a single Claude session** — no external orchestration needed.

For fully automated pipelines (no manual stages), Claude chains through all stages in one session:
1. Hook claims job → Claude works on it
2. Claude runs `hootty pipeline advance` → sees next prompt → works on it
3. Claude runs `hootty pipeline advance` → sees next prompt → works on it
4. Claude runs `hootty pipeline advance` → sees "completed" → claims next job or stops

### Stage Commands and Slash Commands

Stage `command` fields can be anything you'd type into a Claude session:

```yaml
stages:
  - name: Research
    type: automated
    command: "Research the codebase relevant to this job. Read key files, understand the architecture, and summarize your findings."
  - name: Spec
    type: automated
    command: "Based on your research, write a technical spec for this change."
  - name: Plan
    type: manual              # human reviews the spec
  - name: Execute
    type: automated           # uses the job's own prompt (no command override)
  - name: Test
    type: automated
    command: "Write tests for the changes you just made. Run them and fix any failures."
  - name: Review
    type: manual              # human reviews implementation
  - name: Commit
    type: automated
    command: "/commit"        # Claude Code slash command
  - name: Done
    type: manual
```

The `command` field accepts:
- **Prompts** — natural language instructions ("write tests for...")
- **Slash commands** — `/commit`, `/review-pr`, any custom Claude Code skill
- **Shell-style** — `make test && hootty pipeline advance` (for non-Claude runners)
- **null** — uses the job's own prompt (the markdown body)

When `hootty pipeline advance` outputs a slash command like `/commit`, Claude sees it and executes it natively. No special handling — it's just text that Claude interprets.

### Prompt Variables

Job prompts and stage commands support `{{variable}}` placeholders resolved at execution time.

**Resolution order:**
1. **Built-in**: `{{job}}` (slug), `{{stage}}` (current stage name), `{{pipeline}}` (pipeline name), `{{repo}}` (repo root path)
2. **Job frontmatter**: `{{title}}`, `{{priority}}`, `{{labels}}`, etc.
3. **Pipeline variables**: `settings.variables` from `pipeline.yaml`
4. **Environment**: `{{ENV_VAR}}`
5. **Unresolved**: left as-is with a warning (don't block the agent)

### Workflow

1. Developer creates a pipeline and adds jobs (via CLI, Hootty UI, or editing files)
2. Developer opens Claude Code in the project
3. `session_start` hook injects board awareness (pipelines, queued jobs)
4. User tells Claude to pick up a task → Claude runs `hootty pipeline claim --format context`
5. Claude works on the job using its normal tools
6. When done, Claude runs `hootty pipeline advance` via Bash
7. `hootty pipeline advance` outputs the next stage's prompt (or "waiting for human")
8. If automated → Claude sees the prompt and continues working
9. If manual → Claude sees "waiting", claim is released, Claude stops
10. User reviews, then tells Claude to advance or starts a new session
11. Repeat

**Parallel sessions**: Open 3 terminals, each starts Claude Code. Tell each to `hootty pipeline claim`. Each claims a different job. Three jobs progress simultaneously.

### Why Not MCP?

Claude Code can already run shell commands via Bash. `hootty pipeline status --json` gives the same data as an MCP resource. `hootty pipeline advance` does the same thing as an MCP tool call. MCP adds a persistent server process and protocol complexity for zero additional capability.

The CLI approach also means **any AI agent** that can run shell commands works — not just Claude Code with MCP support.

### Multi-agent: Parallel Sessions & Worktrees

Multiple sessions claim different jobs from the same pipeline. **Each parallel session must work in its own git worktree** — otherwise multiple Claude instances edit the same files and cause conflicts.

#### Why Worktrees

Each job may touch overlapping files. Without isolation, two Claude sessions editing the same file create conflicts in the working tree. Git worktrees give each session its own working copy on its own branch.

#### `.hootty/pipeline/` Resolution: Always Canonical Root

The pipeline CLI **always** operates on `.hootty/pipeline/` at the **canonical repo root** (main worktree), never the worktree's local copy. This is critical — each worktree branch has its own `.hootty/pipeline/` snapshot, but pipeline state must be shared.

```
Main repo (~/repos/myproject/)
├── .hootty/pipeline/                    ← CLI reads/writes HERE, always
│   ├── .state.json               ← shared claims across all sessions
│   ├── feature/
│   │   ├── pipeline.yaml
│   │   ├── backlog/001-auth.md
│   │   └── implement/002-fix.md
│   └── ...
├── .claude/worktrees/
│   ├── pipeline/001-auth/        ← worktree for job 001
│   │   ├── .hootty/pipeline/            ← IGNORED by CLI (stale branch copy)
│   │   └── Sources/...           ← code changes happen here
│   └── pipeline/002-fix/         ← worktree for job 002
│       ├── .hootty/pipeline/            ← IGNORED by CLI
│       └── Sources/...
└── Sources/...
```

The CLI resolves the canonical root using `git rev-parse --git-common-dir` (parent of the shared `.git` directory). This returns the same path whether called from the main repo or any worktree.

#### `hootty pipeline claim --worktree`

One command for isolated parallel work:

```bash
$ hootty pipeline claim --worktree
✓ Created worktree: .claude/worktrees/pipeline/001-auth-refactor (branch: pipeline/001-auth-refactor)
✓ Claimed job: 001-auth-refactor (stage: Implement)
▶ Working directory: ~/repos/myproject/.claude/worktrees/pipeline/001-auth-refactor
▶ Prompt:
Refactor the auth module to use async/await...
```

Steps:
1. Claims next available job from the canonical `.hootty/pipeline/`
2. Creates a git worktree + branch: `.claude/worktrees/pipeline/<slug>` (matches Hootty's existing worktree convention)
3. Outputs the worktree path for the caller to `cd` into
4. Outputs the job prompt

#### Hootty Integration with Worktrees

Hootty already has `GitWorktreeManager` with `canonicalRepoRoot(for:)` and `resolveWorktreePath(repoPath:branch:)`. The pipeline integration uses these directly:

**Pipeline bar detection**: Uses `canonicalRepoRoot` (via `Pane.repoRoot`) to find `.hootty/pipeline/`, not `Pane.workingDirectory`. A pane in a worktree at `.claude/worktrees/pipeline/001-auth/` sees the same pipeline state as a pane in the main repo.

**Board view**: Always shows `.hootty/pipeline/` from `canonicalRepoRoot` of the focused pane. Same board whether you're in the main repo or any worktree.

**"Claim in Worktree" board action**: Right-click a job card → "Claim in Worktree":
1. Calls `GitWorktreeManager.resolveWorktreePath(repoPath:, branch: "pipeline/<slug>")`
2. Opens a new pane in the worktree directory (existing `splitFocusedPane(workingDirectory:)`)
3. Registers parent surface for the new pane (inherits ghostty config)
4. Runs `hootty pipeline claim --job <slug>` in the new pane
5. Pipeline bar appears, referencing canonical root's `.hootty/pipeline/`

**Worktree cleanup**: When a job moves to Done and its branch is merged, the worktree can be removed. `hootty pipeline archive` could optionally clean up worktrees for archived jobs. Hootty's sidebar already shows worktrees — a "Clean up worktree" action on completed job cards.

**FSEvents scope**: Hootty watches `.hootty/pipeline/` at `canonicalRepoRoot`, not per-worktree. One watcher per repo, regardless of how many worktree panes exist.

#### Manual Worktree Setup (Without Hootty)

```bash
# Create worktrees manually
git worktree add .claude/worktrees/pipeline/001-auth -b pipeline/001-auth-refactor
git worktree add .claude/worktrees/pipeline/002-fix -b pipeline/002-fix-sidebar

# Each terminal cds into its worktree and claims
cd .claude/worktrees/pipeline/001-auth && hootty pipeline claim --job 001-auth-refactor
cd .claude/worktrees/pipeline/002-fix && hootty pipeline claim --job 002-fix-sidebar
```

#### Single Session (No Worktree)

If you're only running one job at a time, worktrees aren't needed. Work directly in the main repo.

#### Concurrency Limit

```yaml
# pipeline.yaml
settings:
  max_claims: 3                    # max simultaneous claimed jobs (default: unlimited)
```

## CLI Tool: `hootty pipeline`

### Implementation

The CLI is a standalone binary (Swift or Rust). It can operate in two modes:

1. **Direct mode** (no daemon): reads/writes `.hootty/pipeline/` files directly
2. **Client mode** (daemon running): sends commands over Unix socket

The CLI auto-detects: if `.hootty/pipeline/pipeline.sock` exists in the repo and is live, use client mode. Otherwise, direct mode.

### Core Commands

All commands accept an optional pipeline name as the first positional argument. If omitted, the default pipeline from `config.yaml` is used. `hootty pipeline advance` and `hootty pipeline release` always operate on the session's current claim (no pipeline argument needed).

```
# Pipeline management
hootty pipeline init [<name>] [--template]  Create a pipeline (default: "default")
hootty pipeline delete <name> [--yes]       Delete a pipeline (requires confirmation)
hootty pipeline status [<name>] [--all]     Show board state
hootty pipeline play [<name>]               Resume engine
hootty pipeline pause [<name>]              Pause engine

# Job management
hootty pipeline add [<name>] <title>        Add job (stub file, empty body)
hootty pipeline add [<name>] <title> --edit Open $EDITOR after creating stub
hootty pipeline add [<name>] <title> --body "text"  Create with prompt body
hootty pipeline edit <job>                   Open job file in $EDITOR
hootty pipeline edit memory                  Edit shared memory.md
hootty pipeline move <job> <stage>          Move job to specific stage (forward or backward)
hootty pipeline remove <job>                Delete a job
hootty pipeline archive [<name>]            Move done jobs to archive directory
hootty pipeline log <message>               Append note to claimed job

# Claiming
hootty pipeline claim [<pipeline>]          Claim next job from pipeline (default if omitted)
hootty pipeline claim --job <slug>          Claim a specific job by slug (unambiguous)
hootty pipeline claim --stage <stage>       Claim from a specific stage
hootty pipeline claim --force --job <slug>  Override an existing claim
hootty pipeline claim --worktree            Create git worktree + branch, cd into it, then claim
hootty pipeline advance                     Advance claimed job (outputs next prompt)
hootty pipeline release                     Release claim without advancing
hootty pipeline current-job [--format ctx]  Show claimed job (without claiming a new one)
hootty pipeline reap                        Clean up claims from dead sessions
hootty pipeline whoami                      Show session ID and current claim

# Stage management
hootty pipeline stage add <name> [--type auto|manual] [--after <stage>]
hootty pipeline stage remove <name>         Moves jobs to previous stage
hootty pipeline stage move <name> --after <stage>

# Daemon
hootty pipeline daemon start|stop|status    Manage daemon
hootty pipeline inject-target [--pane <id>] Set injection target (Hootty auto-execution)
```

## Templates

```
hootty pipeline init --template simple             # creates .hootty/pipeline/default/
hootty pipeline init feature --template review     # creates .hootty/pipeline/feature/
hootty pipeline init bugs --template simple        # creates .hootty/pipeline/bugs/
hootty pipeline init release --template custom     # creates .hootty/pipeline/release/
```

| Template | Stages |
|----------|--------|
| **simple** | Backlog (manual) → Run (auto) → Done |
| **review** | Backlog (manual) → Implement (auto) → Review (manual) → Done |
| **full-ci** | Backlog (manual) → Implement (auto) → Review (manual) → Test (auto, `"write tests"`) → Commit (auto, `/commit`) → Done |
| **custom** | Interactive stage builder |

## Persistence & Git

### What Gets Committed

```
.hootty/pipeline/
├── config.yaml          ✓ commit (repo-level config)
├── memory.md            ✓ commit (shared context)
├── feature/             ✓ commit (pipeline + jobs)
│   ├── pipeline.yaml
│   ├── backlog/*.md
│   ├── implement/*.md
│   └── done/*.md
├── bugs/                ✓ commit
│   ├── pipeline.yaml
│   ├── triage/*.md
│   └── done/*.md
└── .state.json          ✗ gitignore (runtime state)
```

`.state.json` is in `.gitignore`. Everything else is git-tracked. Teams can share pipelines, review job prompts in PRs, and maintain a history of work items.

### Session Resume

On daemon restart:
1. Scan `.hootty/pipeline/*/pipeline.yaml` to discover all pipelines + their stages
2. Scan each pipeline's stage directories for job files
3. Read `.state.json` if exists — reset any `active` jobs to `interrupted`, clear claims
4. Wait for sessions to reconnect
5. User resumes with `hootty pipeline play [<name>]`

## Implementation Plan

### Phase 1: File Format + CLI (standalone)
- [ ] Define file format: `config.yaml`, `pipeline.yaml`, job markdown spec, `.state.json`
- [ ] Multi-pipeline directory structure (`.hootty/pipeline/<name>/`)
- [ ] `hootty pipeline` CLI: `init`, `delete`, `status`, `add`, `claim`, `advance`, `release`, `move`, `remove`, `archive`, `log`, `whoami`, `reap` (direct mode only)
- [ ] `hootty pipeline stage` subcommands: `add`, `remove`, `move`
- [ ] Session identity resolution (`$PIPELINE_SESSION`, `$CLAUDE_SESSION_ID`, `$PPID`)
- [ ] Advisory file lock (`flock`) on `.state.json` for concurrent write safety
- [ ] Stale claim detection (PID check on claim/advance, `--force` override)
- [ ] Claim priority order (interrupted → queued, by filename sort)
- [ ] `hootty pipeline claim --worktree` (create git worktree + branch for isolated parallel work)
- [ ] Job auto-numbering (incrementing integer across all stages)
- [ ] Job log appending (`## Log` section in job file)
- [ ] Prompt variable resolution (built-in → frontmatter → settings → env)
- [ ] Templates: simple, review, full-ci
- [ ] Unit tests for file parsing, job movement, claim/release, stale cleanup, variable resolution

### Phase 2: Daemon + Socket
- [ ] `hootty pipeline daemon` process (Swift or Rust)
- [ ] Unix socket server: accept commands, emit events
- [ ] Execution engine: idle detection, auto-advance, error interrupts
- [ ] `hootty pipeline inject-target` for Hootty pane auto-execution
- [ ] File watching: sync `.hootty/pipeline/` changes into daemon state

### Phase 3: Claude Code Hooks
- [ ] `hootty pipeline status --format context` for session_start hook (awareness, not auto-claim)
- [ ] `hootty pipeline claim --format context` for explicit claiming
- [ ] Hook templates / setup command (`hootty pipeline init --hooks`)
- [ ] Document Bash-based workflow (claim, advance, status, add from within Claude)

### Phase 4: Hootty UI
- [ ] Title bar view switcher: Terminals | Pipelines
- [ ] Pipeline bar (per-pane, below pane bar, shown when claimed)
- [ ] FSEvents watcher for `.hootty/pipeline/` directory
- [ ] Claim-to-pane matching (claudeSessionID, PID, $PIPELINE_SESSION)
- [ ] Kanban board view: stage columns, job cards, drag-and-drop (forward + backward)
- [ ] Inline card creation: `[+ Add]` → type title → Enter → stub file
- [ ] Card detail view: prompt preview, stage outputs, log, metadata, actions
- [ ] Column header context menu: Add Stage After, Remove Stage, Change Type
- [ ] Pipeline selector (multi-pipeline repos)
- [ ] Board ↔ Terminal navigation (click card → focus pane, click pipeline bar → show board)
- [ ] Pipeline creation/deletion flow + template picker
- [ ] Archive section (collapsible, shows archived jobs)
- [ ] Attention integration (badge on Pipelines tab, pane attention for interrupted jobs)

### Phase 5: Polish
- [ ] Multi-runner concurrency
- [ ] Web UI / TUI client
- [ ] Pipeline templates marketplace / sharing
- [ ] Job dependencies (DAG)
- [ ] Cross-pipeline coordination
- [ ] Variable resolution from previous job output

## Behavioral Rules

### Job File Naming

**Slug derivation**: Title is lowercased, non-alphanumeric characters replaced with hyphens, consecutive hyphens collapsed, max 50 characters. `"Refactor Auth Module!"` → `refactor-auth-module`.

**Auto-numbering**: Zero-padded to 3 digits (`001`, `002`, ..., `999`). Scan all files across all stages in the pipeline, take max prefix + 1. File creation is covered by the same `flock` on `.state.json` to prevent race conditions (extend the lock scope to cover add operations).

**Sort order**: Numeric-aware sort on the prefix (not lexicographic). `001` < `002` < `010` < `100`.

### Stage Directory Lifecycle

**Stage directories are auto-created**: When `hootty pipeline init` creates a pipeline or `hootty pipeline stage add` adds a stage, the corresponding directory is created. If a stage is listed in `pipeline.yaml` but its directory is missing, the CLI auto-creates it on first use.

**Orphan directories** (exist on disk but not in `pipeline.yaml`) are ignored by the CLI. Their files are invisible to the pipeline.

**"Done" is not special**: It's a regular stage listed in `pipeline.yaml`. The execution engine advances through stages in order — when there's no next stage after the last one, the job is marked `completed`. The last stage is conventionally called "Done" but can be named anything.

### Remove / Delete Guards

**`hootty pipeline remove <job>` with active claim**: Releases the claim, then deletes the file. Appends a log entry before deletion ("Removed by user"). The claiming session's next `hootty pipeline advance` will fail with "No active claim."

**`hootty pipeline stage remove` with claimed jobs**: Moves jobs to previous stage, preserves claims. The claiming session continues working — the job just moved to a different directory.

### Advance Guards

**`hootty pipeline advance` without claim**: Error, exit code `1`: "No active claim. Run `hootty pipeline claim` first."

**Double advance prevention**: `hootty pipeline advance` checks that the job is still in the expected stage before moving it. If the job has already been moved (by another process or UI drag), it errors: "Job has moved since your last action. Run `hootty pipeline current-job` to see current state."

**`hootty pipeline play` / `hootty pipeline pause` without daemon**: The `paused` flag is written to `.state.json`. `hootty pipeline advance` checks it and errors: "Pipeline is paused." `hootty pipeline claim` also checks it and errors: "Pipeline is paused."

### Fresh Clone / Missing State

When `.state.json` doesn't exist (fresh `git clone`, first use), the CLI creates it on first invocation. All jobs default to `queued` status. No claims. Pipeline not paused.

### `$EDITOR` Fallback

`hootty pipeline edit` tries `$EDITOR`, then `$VISUAL`, then `vi`. If none available, errors: "No editor found. Set $EDITOR."

## Known Limitations

These are acknowledged but deferred to implementation time or future phases:

- **Corrupt YAML/JSON recovery**: If `pipeline.yaml` or `.state.json` is malformed, the CLI errors with a parse error and line number. No auto-recovery. User must fix manually. `.state.json` can be safely deleted (regenerated from filesystem on next CLI call).
- **Git merge conflicts**: `.hootty/pipeline/` files are plain text and merge normally. Log entries may conflict (both branches appended). Job files moved to different stages on different branches cause delete/add conflicts. No special merge driver — resolve like any git conflict.
- **`memory.md` / job file size**: No built-in size limits. If files grow large and consume Claude's context window, the user should trim them. Future: `--max-context` flag on `hootty pipeline claim`.
- **PID recycling**: `kill -0` may find a recycled PID from an unrelated process, preventing stale claim reaping. Rare in practice. `hootty pipeline claim --force` is the escape hatch.
- **Multiple daemons**: Each repo with `.hootty/pipeline/` gets its own daemon process (one daemon per repo). Socket at `.hootty/pipeline/pipeline.sock`. No cross-repo daemon.
- **Custom template saving**: No mechanism to save a `pipeline.yaml` as a reusable template in Phase 1. Copy the file manually. Templates marketplace is Phase 5.
- **`.hootty/pipeline/` in worktrees**: Each worktree branch has its own `.hootty/pipeline/` snapshot, but the CLI always resolves to the canonical repo root's `.hootty/pipeline/` via `git rev-parse --git-common-dir`. The worktree's local `.hootty/pipeline/` copy is stale and ignored. Hootty uses `GitWorktreeManager.canonicalRepoRoot(for:)` for the same resolution.

## Open Questions

1. **CLI language** — Swift (shared code with Hootty) vs Rust (faster standalone binary, cross-platform)? Swift makes sense if the daemon shares HoottyCore models.
2. **Daemon lifecycle** — Auto-start when CLI is used? Launchd service? Or always explicit `hootty pipeline daemon start`?
3. **Scope** — Should this be a Hootty feature, a standalone open-source tool, or both? The architecture supports either — the daemon/CLI is independent, Hootty is just a UI client.

## Resolved Gaps

All 27 known gaps have been resolved. See [PIPELINE_GAPS.md](./PIPELINE_GAPS.md) for the full decision log.
