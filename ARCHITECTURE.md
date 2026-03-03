# Claude Code Orchestrator — macOS Native Architecture

## Overview

A native macOS application for orchestrating multiple Claude Code agent sessions with a kanban-style task board and embedded terminal access. Agents run autonomously, report status via Claude Code hooks, and users can jump into any live session through embedded terminal views.

---

## Core Design Principles

- **Native-first**: Swift/SwiftUI with direct POSIX PTY management — no browser runtime, no WebSocket bridges.
- **Embedded terminal**: libghostty provides GPU-accelerated, standards-compliant terminal rendering as a library, eliminating the need for xterm.js or third-party terminal widgets.
- **Hooks as the event bus**: Claude Code hooks are the sole integration point between agents and the UI. No custom Claude Code patches or forks required.
- **Process isolation**: Each agent runs as an independent child process in its own PTY. Crashes are contained. Sessions can be killed, restarted, or attached to independently.

---

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Layer                     │
│                                                      │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Sidebar  │  │ Kanban Board │  │Terminal Panel │  │
│  │          │  │              │  │               │  │
│  │ Projects │  │  Planning    │  │  libghostty   │  │
│  │ Agents   │  │  In Progress │  │  embedded     │  │
│  │ Settings │  │  Review      │  │  terminal     │  │
│  │          │  │  Done        │  │               │  │
│  └──────────┘  └──────┬───────┘  └───────┬───────┘  │
│                       │                   │          │
└───────────────────────┼───────────────────┼──────────┘
                        │                   │
              ┌─────────▼─────────┐         │
              │  Orchestrator     │         │
              │  (Swift)          │         │
              │                   │         │
              │  - Task state     │         │
              │  - Agent registry │         │
              │  - Hook listener  │         │
              │  - PTY manager    ◄─────────┘
              └────────┬──────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
   ┌──────▼──┐  ┌──────▼──┐  ┌──────▼──┐
   │ Agent 1  │  │ Agent 2  │  │ Agent N  │
   │          │  │          │  │          │
   │ claude   │  │ claude   │  │ claude   │
   │ (PTY 1)  │  │ (PTY 2)  │  │ (PTY N)  │
   └──────────┘  └──────────┘  └──────────┘
```

---

## Component Breakdown

### 1. PTY Manager

Responsible for spawning and managing Claude Code child processes.

**Responsibilities:**
- Spawn Claude Code sessions via `forkpty()` / `posix_spawn` with pseudo-terminal allocation
- Maintain a registry of active PTY file descriptors mapped to agent IDs
- Provide read/write access to any session's PTY for the terminal panel
- Handle process lifecycle: start, signal, kill, restart
- Buffer recent output per-session so the terminal panel can "catch up" on attach

**Key interfaces:**
```swift
class PTYManager {
    func spawn(agentId: String, command: [String], env: [String: String]) -> PTYSession
    func attach(agentId: String) -> PTYSession   // returns fd for terminal rendering
    func detach(agentId: String)
    func kill(agentId: String, signal: Int32)
    func listSessions() -> [AgentSession]
}

struct PTYSession {
    let agentId: String
    let pid: pid_t
    let fd: Int32              // PTY master file descriptor
    let startedAt: Date
    var status: AgentStatus    // .running, .idle, .exited(code)
}
```

**Claude Code invocation:**
```bash
# Headless mode with streaming JSON output
claude --output-format stream-json -p "implement feature X"

# Or interactive mode for sessions the user may take over
claude
```

### 2. Hook Listener

Claude Code hooks write structured events that drive the kanban board state.

**Mechanism:** Hooks are configured as shell scripts in `.claude/settings.json` that write JSON events to a Unix domain socket or a shared directory the app monitors.

**Hook configuration (.claude/settings.json):**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "echo '{\"event\":\"tool_use\",\"agent\":\"$AGENT_ID\",\"tool\":\"'$(cat /dev/stdin | jq -r .tool_name)'\",\"ts\":'$(date +%s)'}' | nc -U /tmp/orchestrator.sock"
        }]
      }
    ],
    "Stop": [
      {
        "hooks": [{
          "type": "command",
          "command": "echo '{\"event\":\"agent_stop\",\"agent\":\"$AGENT_ID\",\"ts\":'$(date +%s)'}' | nc -U /tmp/orchestrator.sock"
        }]
      }
    ],
    "Notification": [
      {
        "hooks": [{
          "type": "command",
          "command": "echo '{\"event\":\"notification\",\"agent\":\"$AGENT_ID\",\"message\":\"'$(cat /dev/stdin | jq -r .message)'\"}' | nc -U /tmp/orchestrator.sock"
        }]
      }
    ]
  }
}
```

**App-side listener:**
```swift
class HookListener: ObservableObject {
    @Published var events: [AgentEvent] = []

    func startListening(socketPath: String)   // bind Unix domain socket
    func processEvent(_ data: Data)           // parse JSON, update state
}
```

**Event types:**
| Event | Source Hook | Triggers |
|---|---|---|
| `task_started` | SessionStart | Card moves to In Progress |
| `tool_use` | PostToolUse | Activity indicator on card |
| `agent_stop` | Stop | Card moves to Review |
| `needs_input` | Notification | Card flagged, macOS notification |
| `task_complete` | TaskCompleted | Card moves to Done |
| `error` | Stop (non-zero) | Card flagged red |

### 3. Terminal Panel (libghostty)

Embeds a real terminal emulator in the app using Ghostty's library.

**Integration approach:**
- Link against libghostty's C API
- Create a Swift wrapper around the libghostty surface/rendering APIs
- Feed PTY file descriptor output into libghostty for rendering
- Forward keyboard input from the NSView/SwiftUI view back to the PTY fd

```swift
class GhosttyTerminalView: NSViewRepresentable {
    let ptySession: PTYSession

    // libghostty handles:
    // - GPU-accelerated rendering (Metal on macOS)
    // - Font shaping and ligatures
    // - Terminal sequence parsing
    // - Scrollback buffer
    // - Selection and copy/paste
}
```

**Attach/detach flow:**
1. User clicks agent card or selects from sidebar
2. Terminal panel calls `ptyManager.attach(agentId)`
3. GhosttyTerminalView binds to the PTY fd
4. User sees live terminal output, can type to interact
5. Switching agents detaches the current view and attaches the new one

**Fallback:** If libghostty's API proves too unstable in early stages, a simpler fallback is rendering the `--output-format stream-json` output as a structured activity log (not a full terminal, but still useful).

### 4. Kanban Board

SwiftUI-driven task management board.

**State model:**
```swift
enum TaskStage: String, CaseIterable {
    case planning
    case inProgress
    case aiReview
    case humanReview
    case done
}

struct AgentTask: Identifiable {
    let id: UUID
    var title: String
    var description: String
    var stage: TaskStage
    var agentId: String?
    var progress: Double        // 0.0 - 1.0
    var labels: [String]        // e.g. "Performance", "High Impact"
    var lastActivity: Date
    var commits: [String]       // associated commit SHAs
}
```

**Interactions:**
- Drag-and-drop cards between columns
- Click card → opens terminal panel for that agent
- "Start" button on planning cards → spawns a new Claude Code session
- Manual override: user can move cards regardless of hook state

### 5. Project Configuration

**Per-project config (stored alongside .claude/):**
```yaml
# .orchestrator/config.yaml
project:
  name: "autonomous-coding"
  root: "/Users/dev/Documents/project"

agents:
  max_concurrent: 4
  default_model: "claude-sonnet-4-5-20250929"
  timeout_minutes: 30

hooks:
  socket_path: "/tmp/orchestrator.sock"

tasks:
  auto_review: true           # AI review before human review
  require_tests: true         # Block completion without passing tests
```

---

## Data Flow

```
User creates task in Kanban
        │
        ▼
Orchestrator spawns Claude Code in PTY
  with task description as prompt
  with project hooks configured
        │
        ├──► Claude Code runs autonomously
        │         │
        │         ├── PostToolUse hook ──► socket ──► UI updates activity
        │         ├── Notification hook ──► socket ──► UI shows alert
        │         └── Stop hook ──────────► socket ──► UI moves card
        │
        ├──► User clicks "View Terminal"
        │         │
        │         ▼
        │    libghostty attaches to PTY fd
        │    User sees live session, can type
        │
        └──► Agent finishes
              │
              ▼
         Card moves to Review
         User inspects diff, approves or sends back
```

---

## Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| UI Framework | SwiftUI + AppKit | Native macOS look and feel, sidebar/split views |
| Terminal Rendering | libghostty (C API) | GPU-accelerated, Metal, full terminal compliance |
| Process Management | POSIX `forkpty` | Direct PTY control, no intermediary layers |
| IPC (hooks → app) | Unix domain socket | Low-latency, local-only, simple JSON protocol |
| Persistence | SQLite (via SwiftData) | Task history, agent logs, project config |
| Agent Runtime | Claude Code CLI | Headless or interactive mode per session |
| Notifications | UserNotifications framework | Native macOS notifications for agent alerts |

---

## Key Risks and Mitigations

**libghostty API instability**
The API isn't stable yet. Mitigation: wrap in a thin abstraction layer. Fallback to a basic ANSI renderer or raw text log view if the API breaks between versions.

**Claude Code hook limitations**
Hooks are shell commands that receive JSON on stdin. Complex state tracking may require a helper daemon. Mitigation: keep the hook scripts thin — they just forward events to the socket. All logic lives in the Swift app.

**PTY management complexity**
Managing multiple PTYs, handling window resizing (SIGWINCH), and cleaning up zombie processes requires care. Mitigation: use a dedicated PTYManager actor with proper lifecycle handling and watchdog timers.

**Zig/C interop with Swift**
libghostty is Zig compiled to a C ABI. Swift can call C, but the bridging header and memory management need attention. Mitigation: build a small C wrapper if needed, use Swift's `UnsafePointer` APIs carefully.

---

## MVP Scope

**Phase 1 — Terminal + Task Board (4-6 weeks)**
- Spawn Claude Code in PTY sessions
- Basic kanban board with manual card management
- Embedded terminal view (start with basic NSTextView + ANSI parsing, upgrade to libghostty)
- Hook listener updating card status

**Phase 2 — Agent Orchestration (3-4 weeks)**
- Multi-agent concurrent execution
- Task assignment and progress tracking
- AI review stage (agent reviews agent output)
- Git integration (branch per task, auto-commit)

**Phase 3 — Polish (2-3 weeks)**
- libghostty integration for terminal rendering
- Drag-and-drop kanban
- Project templates and saved configurations
- Menu bar status indicator
- Keyboard-driven workflow (switch agents, quick commands)
