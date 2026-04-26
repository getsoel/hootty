---
name: review
description: Review all changed files for reuse, quality, efficiency, and blueprint compliance.
---

0. **Worktree check**: `blueprint:*` commands run inside a blueprint worktree. Verify `contractor/` exists in CWD and you are on a `contractor/<name>` branch rather than the blueprint's base branch (the branch you started from):
   ```
   test -d contractor && git rev-parse --abbrev-ref HEAD
   ```
   If `contractor/` is missing or HEAD is still on the base branch, refuse with: "`blueprint:*` commands must run from inside a worktree. `cd` into `contractor/.worktrees/<name>/` first, or run `/contractor:propose` to create a new blueprint."

1. **Detect active blueprint**:
   ```
   contractor blueprint show --json
   ```
   A worktree should have exactly one active blueprint (the one matching its branch). If none is found, report the error to the user and stop — do not fall back to `blueprint list`.


## Phase 1: Identify Changes

Run `contractor blueprint show --json` to find the active change.

Read all artifacts for context:
- All files in `contractor/blueprints/<name>/` (proposal, requirements, design, tasks)

Run `git diff` (or `git diff HEAD` if there are staged changes) to see what changed.

## Phase 2: Launch Review Agents in Parallel

Use the Agent tool to launch all 4 agents concurrently in a single message. Pass each agent the full diff so it has the complete context.

### Agent 1: reuse

For each change:
1. Search for existing utilities and helpers that could replace newly written code.
2. Flag any new function that duplicates existing functionality.
3. Flag any inline logic that could use an existing utility.


### Agent 2: quality

Review changes for hacky patterns:
1. Redundant state that duplicates existing state
2. Parameter sprawl instead of restructuring
3. Copy-paste with slight variation
4. Leaky abstractions breaking encapsulation
5. Stringly-typed code where constants or enums exist
6. Unnecessary comments explaining WHAT instead of WHY


### Agent 3: efficiency

Review changes for efficiency:
1. Unnecessary work: redundant computations, repeated file reads, N+1 patterns
2. Missed concurrency: independent operations run sequentially
3. Hot-path bloat: blocking work on startup or per-request paths
4. Recurring no-op updates without change detection
5. Memory: unbounded data structures, missing cleanup
6. Overly broad operations: reading entire files when only a portion is needed


### Agent 4: blueprint-compliance

Verify implementation against artifacts. Check:

Completeness:
- All tasks checked off, all requirements implemented, all scenarios covered

Correctness:
- Implementation matches spec intent, edge cases handled

Coherence:
- Design decisions reflected in implementation, patterns consistent

Report: PASS / FAIL / WARN for each requirement.


## Phase 3: Fix Issues

Wait for all agents to complete. Aggregate their findings and fix each issue directly. If a finding is a false positive or not worth addressing, note it and move on.

When done, briefly summarize what was fixed (or confirm the code was already clean).

## Before finishing

Write observations to `contractor/.observations/<change>/<phase>.json` — things you noticed but did not act on:
- Code issues you chose not to fix (wrong scope, pre-existing, too large)
- Conventions that should be rules but are not documented
- Task descriptions that did not match reality
- Friction that a tooling or workflow change could eliminate

Write a JSON array of objects: `{ "kind": "code" | "rule" | "process", "summary": "<one line>", "location": "<file:line>", "detail": "<explanation>" }`.
Omit `location` for `process` observations. Write `[]` if you have no observations — do not manufacture items to fill the form.

## Phase Instructions

Review all changed files for reuse, quality, efficiency, and blueprint compliance.
Fix any issues found.
