# Reflection: pin-workspace

> Clean removal-heavy change completed across two short apply sessions with minimal friction — replaced ~800 lines of docked panel complexity with ~50 lines of workspace pinning.

## Progress

- Completed: 7/7 task groups, 63/63 individual tasks
- Group 1: Remove Docked Panel Model & Persistence (9 tasks)
- Group 2: Add Pin Workspace Model & Persistence (5 tasks)
- Group 3: Remove Docked Panel Commands (5 tasks)
- Group 4: Add Pin Workspace Commands (4 tasks)
- Group 5: Remove Docked Panel UI (10 tasks)
- Group 6: Add Pin Workspace Sidebar UI (3 tasks)
- Group 7: Update Tests (5 tasks)

## Session Summary

Four sessions total:
1. **Apply session 1** (16:22–16:37) — "Apply all remaining task groups" — completed the bulk of the work across all 7 groups. Hit 3 EISDIR errors reading spec directories and 1 token-limit error reading IntegrationTests.swift.
2. **Apply session 2** (21:46–21:49) — "Apply all remaining task groups" — short continuation, hit 2 more token-limit errors on IntegrationTests.swift.
3. **Review session** (21:49–21:54) — "Review implementation for quality and spec compliance" — 1 more token-limit error on IntegrationTests.swift. No issues found.
4. **Reflect + archive** (22:38–22:40) — produced initial reflection and archived.

## Friction Points

1. **What happened** — Read tool tried to read spec directories instead of `spec.md` files within them, producing 3 EISDIR errors at session start.
   **Why** — Specs are organized as `specs/<name>/spec.md` directories, but the agent attempted `Read` on the directory path without the `/spec.md` suffix.
   **Where** — `workshop/changes/pin-workspace/specs/pin-workspace-model/`, `pin-workspace-commands/`, `pin-workspace-sidebar/`

2. **What happened** — `IntegrationTests.swift` exceeded the Read tool's token limit (15360–16382 tokens), requiring retries with offset/limit across 3 of the 4 sessions (4 occurrences total).
   **Why** — The file is large (~1300 lines) and the agent initially tried to read it without offset/limit parameters each time a new session started.
   **Where** — `Tests/HoottyCoreTests/IntegrationTests.swift`

## Convention Gaps

No convention gaps observed. The implementation correctly follows existing patterns:
- `opacity(0/1)` for the pin icon instead of conditional insertion (per SwiftUI rule about layout stability)
- Design tokens used throughout (`tokens.textMuted`, `TypeScale.captionSize`)
- Context menu items follow existing naming patterns ("Pin Workspace" / "Unpin Workspace")
- Tests use the established `makeModel()` pattern with temp file URLs
- `sortedWorkspaces` computed at render time preserves underlying array order (per design decision)

## Spec Ambiguities

No spec ambiguities observed. All three specs were precise about what to add, what to remove, and what to modify. The implementation matches spec requirements 1:1.

## Suggested Rules

```markdown
# Target: .claude/rules/coding/testing.md

When reading `IntegrationTests.swift` (or any test file exceeding ~10K tokens), always use `offset` and `limit` parameters on the Read tool. The file regularly exceeds the default token limit. Read in chunks of 300–400 lines.
```
