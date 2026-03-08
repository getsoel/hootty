# Pipeline — Spec

## Overview

A kanban-style pipeline system where jobs progress through ordered stages. Each stage is either **automated** (Claude executes immediately when a job arrives) or **manual** (waits for user approval before advancing). A pipeline is bound to a single terminal pane, and jobs execute sequentially in that pane's Claude session.

### Terminology

| Term | Definition | Rationale |
|------|-----------|-----------|
| **Pipeline** | Top-level orchestrator for a sequence of terminal tasks | Aligns with CI/CD mental model; "queue" implies passive FIFO |
| **Stage** | A discrete step in the pipeline lifecycle (vertical column) | Standard in CI/CD and DevOps; avoids conflict with Kanban "swimlanes" (horizontal) |
| **Job** | A unit of work that progresses through stages | Standard in terminal/automation contexts (Unix jobs, CI jobs) |
| **Automated** | Stage type that executes without human intervention | Clearer than "auto" |
| **Manual** | Stage type that pauses for human approval | More descriptive of the user's role than "gated"; analogous to a debugger breakpoint or shell SIGTSTP |

## Concepts

### Pipeline
A named sequence of stages, bound to one pane. When the pane's Claude session goes idle, the pipeline engine checks if the next pending action should run automatically or wait. Pipelines live on `AppModel` (not per-workspace) so they can be reused or rebound to different panes.

### Stage
An ordered step in the pipeline. Each stage has:
- **Name** — display label (e.g., "Backlog", "Implement", "Review", "Commit")
- **Type** — `automated` or `manual`
  - `automated`: when a job arrives in this stage, its command is sent to the Claude session immediately
  - `manual`: job waits here until the user explicitly advances it (click or drag)
- **Fixed command** (optional) — a prompt or slash command that runs when jobs enter this stage. If empty, the job's own prompt is used.

### Job
A task that progresses through the pipeline. Each job has:
- **Title** — short display name
- **Prompt** — the text prompt or slash command to send to Claude (supports `{{variables}}`)
- **Current stage** — which stage the job is currently in
- **Status** — `queued` | `active` | `interrupted` | `completed`

## Data Model

```
Pipeline (@Observable, Codable)
├── id: UUID
├── name: String
├── paneID: UUID?              — bound pane (nil = unassigned)
├── stages: [Stage]            — ordered lifecycle stages
├── jobs: [Job]                — all jobs in this pipeline
└── isPaused: Bool             — play/pause engine state

Stage (Codable)
├── id: UUID
├── name: String
├── type: StageType            — .automated | .manual
└── fixedCommand: String?      — prompt override (nil = use job prompt)

Job (@Observable, Codable)
├── id: UUID
├── title: String
├── prompt: String             — text prompt, /command, or template with {{vars}}
├── stageID: UUID              — current stage
└── status: JobStatus          — queued | active | interrupted | completed

StageType: String, Codable
├── .automated                 — execute immediately
└── .manual                    — wait for human

JobStatus: String, Codable
├── .queued                    — in backlog, not yet reached
├── .active                    — currently executing in Claude
├── .interrupted               — paused at a manual stage or error; awaiting user
└── .completed                 — finished all stages
```

### Status mapping to shell states

| Job Status | Shell Equivalent | Description |
|------------|-----------------|-------------|
| `.queued` | Background (not started) | Resides in the backlog buffer |
| `.active` | Foreground / Active | Currently writing to ghostty_surface |
| `.interrupted` | Stopped (SIGTSTP) | Paused at a manual stage or error |
| `.completed` | Terminated (exit 0) | All stages finished |

### Relationship to existing model

```
AppModel
├── workspaces: [Workspace]
├── pipelines: [Pipeline]      — NEW: all pipelines across workspaces
└── ...

Pane (existing)
├── ...existing fields...
├── pipelineID: UUID?          — NEW: bound pipeline (nil = no pipeline)
└── ...
```

The binding is via `Pipeline.paneID` ↔ `Pane.pipelineID`. This enables "pipeline mobility" — detach from one pane and reattach to another.

## Execution Engine

### Core Loop

The `PipelineEngine` hooks into the existing attention system. When a pane signals `AttentionKind.idle`:

```
1. Look up pipeline bound to this pane
2. If pipeline.isPaused → do nothing
3. Find the job currently in `active` status → mark it complete for current stage
4. Advance job to next stage:
   a. If next stage is `automated`:
      - Resolve prompt: stage.fixedCommand ?? job.prompt
      - Run variable substitution on the resolved prompt
      - Send to pane via ghostty_surface_write()
      - Set job status → .active
   b. If next stage is `manual`:
      - Set job status → .interrupted
      - Trigger attention indicator on pane (AttentionKind.input)
   c. If no next stage:
      - Set job status → .completed
      - Pull next queued job from backlog stage (if any) → start it
5. If no active job and backlog has queued jobs:
   - Dequeue first queued job
   - Advance to first automated stage → resolve prompt → send
```

### Dynamic Interrupts

Beyond predetermined manual stages, the engine can auto-pause on errors. If the Claude session signals an error state (e.g., failed test, command error), the engine:

1. Sets the active job's status → `.interrupted`
2. Triggers `AttentionKind.input` on the pane
3. The user can inspect the output, fix the issue, then manually advance

This turns any automated stage into a temporary manual stage when something goes wrong, preventing the pipeline from blindly continuing through failures.

### Human Advancement

When the user advances an interrupted job (click or drag):
1. Move job to the next stage
2. If next stage is `automated` → resolve prompt, send, set `.active`
3. If next stage is also `manual` → keep `.interrupted`

### Fixed Command vs Job Prompt

Each stage can optionally define a `fixedCommand`. This enables reusable pipeline templates:

| Stage | Type | Fixed Command |
|-------|------|---------------|
| Backlog | manual | *(none)* |
| Implement | automated | *(none — uses job prompt)* |
| Review | manual | *(none)* |
| Test | automated | `"write tests for the changes you just made"` |
| Commit | automated | `/commit` |

When `stage.fixedCommand` is set, that string is sent to Claude regardless of the job's prompt. When nil, the job's own prompt is sent.

### Prompt Variables

Job prompts and stage fixed commands support `{{variable}}` placeholders that are resolved at execution time.

```
"refactor {{file}} to use async/await"
"run tests for {{module}}"
```

The `PipelineEngine` runs a pre-processor before sending any prompt:
1. Scan for `{{...}}` patterns
2. Resolve from: job metadata, environment variables, pane working directory
3. If unresolved variables remain → set job status to `.interrupted`, prompt user to fill in values

This enables generic pipeline templates that can be applied across different contexts.

## UI Design

### Sidebar Integration

The pipeline UI lives in the existing left sidebar, below the workspace/pane tree. A collapsible "Pipelines" section shows all pipelines.

```
┌─────────────────────────┐
│ WORKSPACES              │
│ ▼ Default               │
│   ├─ Group 1            │
│   │  ├─ ~ zsh           │
│   │  └─ auth refactor ● │  ← ● = job active
│   └─ Group 2            │
│                         │
│ PIPELINES               │
│ ▼ Auth Pipeline    [▶]  │  ← [▶] play/pause
│   │ Backlog (2)         │
│   │  ├─ task-3          │
│   │  └─ task-4          │
│   │ Implement ▶         │
│   │  └─ task-2 ●        │  ← currently active
│   │ Review ⏸            │
│   │  └─ task-1 ◉        │  ← interrupted, awaiting human
│   │ Commit              │
│   │  └─ (empty)         │
│   └─ Done (0)           │
│                         │
│ [+ New Pipeline]        │
└─────────────────────────┘
```

### Job Interactions

- **Click job** in a manual stage → advances to next stage (or shows confirmation)
- **Drag job** between stages → manual reorder/advancement
- **Right-click job** → context menu: Edit, Delete, Move to stage…
- **Click [+]** on a stage → add new job to that stage

### Pipeline Header Actions

- **Play/Pause** — toggle `isPaused` on the pipeline engine
- **Bind to Pane** — pick which pane this pipeline sends commands to
- **Edit Stages** — add/remove/reorder stages, change types

### Attention Integration

Reuses the existing attention system:
- When a job enters a manual stage or is dynamically interrupted → set `pane.attentionKind = .input`
- When a job is active → pane shows normal running state
- Sidebar shows pipeline status alongside workspace attention dots
- Active job in pane shows a pulsating indicator for continuous visibility

### Visual Feedback

| UI Component | Purpose |
|-------------|---------|
| Collapsible section | Managing sidebar real estate |
| Play/pause icon | Pipeline engine state |
| Attention dot | Job needs human intervention |
| Progress badge | Count of jobs per stage |
| Status indicator | Active/interrupted/completed per job |

## Persistence

### Storage

Pipelines are persisted alongside workspaces in `~/Library/Application Support/Hootty/`:

```
workspaces.json     — existing workspace/pane state
pipelines.json      — NEW: all pipelines, stages, jobs, and their state
```

Uses the same `debouncedSave()` pattern as workspace persistence. Pipeline state (which job is in which stage, status) survives app restart.

### Session Resume

On app restart:
1. Workspace/pane state restored (existing behavior)
2. Pipeline state restored from `pipelines.json`
3. Any job marked `.active` is reset to `.interrupted` (Claude session was severed)
4. User can resume by clicking play on the pipeline → resumes the Claude session in the bound pane

This defensive reset prevents erratic behavior in a potentially corrupted session by forcing human validation before the agent resumes.

## Pipeline Templates

Pre-built stage configurations users can pick from when creating a pipeline:

| Template | Stages |
|----------|--------|
| **Simple** | Backlog (manual) → Run (automated) → Done |
| **Review** | Backlog (manual) → Implement (automated) → Review (manual) → Done |
| **Full CI** | Backlog (manual) → Implement (automated) → Review (manual) → Test (automated, `"write tests"`) → Commit (automated, `/commit`) → Done |
| **Custom** | User defines stages from scratch |

## Implementation Plan

### Phase 1: Core Model (HoottyCore)
- [ ] `Pipeline`, `Stage`, `Job` model types in `Sources/HoottyCore/`
- [ ] `PipelineStore` for persistence (mirrors `WorkspaceStore` pattern)
- [ ] `PipelineEngine` — state machine that processes idle signals and advances jobs
- [ ] Prompt variable pre-processor (`{{var}}` resolution)
- [ ] Unit tests for engine logic (advance, manual pause, dynamic interrupt, fixed commands, variable resolution, backlog dequeue)

### Phase 2: Integration
- [ ] Wire `PipelineEngine` into `AppModel`
- [ ] Hook into `onPaneNeedsAttention` idle signal → trigger engine
- [ ] Send prompts to pane via `GhosttyApp.shared.sendText(paneID:text:)`
- [ ] `Pane.pipelineID` binding
- [ ] Dynamic interrupt on error detection
- [ ] Persist/restore pipeline state

### Phase 3: Sidebar UI
- [ ] "Pipelines" section in sidebar
- [ ] Stage/job tree rendering with status indicators
- [ ] Drag-and-drop between stages
- [ ] Click-to-advance on interrupted jobs
- [ ] Context menus for jobs and stages
- [ ] Pipeline creation flow with template picker

### Phase 4: Polish
- [ ] Attention indicator integration (input attention for manual/interrupted jobs)
- [ ] Play/pause per pipeline
- [ ] Edit stage configuration
- [ ] Pipeline templates
- [ ] Keyboard shortcuts for pipeline operations
- [ ] Visual feedback: pulsating indicators, progress badges

## Open Questions

1. **Concurrent jobs** — Should multiple jobs be able to run simultaneously across different panes, or strictly one-at-a-time per pipeline? (Current spec: one pane per pipeline, sequential)
2. **Error detection heuristics** — How does the engine distinguish a Claude error from normal output? Options: parse exit codes, look for error patterns, rely on attention signals.
3. **Job dependencies (DAG)** — Should jobs be able to declare dependencies on other jobs, or is linear ordering sufficient for v1?
4. **Cross-pipeline coordination** — Should pipelines be able to feed into each other (output of pipeline A → input of pipeline B)?
5. **Variable sources** — Beyond environment and pane context, should variables pull from previous job output or user-defined key-value stores?
