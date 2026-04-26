---
name: implement
description: Implement exactly the assigned task-group, mark its checkboxes, commit, and exit.
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


You implement exactly one task-group from `contractor/blueprints/<name>/tasks.md` per invocation. The pipeline runner expands the `implement` phase into one sub-step per incomplete group; this prompt scopes you to one group only.

Your specific group's number, title, and unchecked tasks are appended below this preamble (or supplied as the user message). Read those, plus `contractor/blueprints/<name>/proposal.md`, `contractor/blueprints/<name>/design.md`, and any files under `contractor/blueprints/<name>/requirements/` to establish shared context.

For each unchecked task in your group:
- Implement the task
- Update its checkbox in `contractor/blueprints/<name>/tasks.md` from `- [ ]` to `- [x]`


Rules:
- Touch only your assigned group's checkboxes. Do NOT modify any `- [x]` or `- [ ]` outside your group.
- `- [-]` checkboxes are manual/deferred items; leave them untouched.
- When every task in your group is done, stage and commit:
  ```
  git add -A && git commit -m "<type>: <description for your group>"
  ```
  Use a Conventional Commits type (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`, `build:`, `perf:`, `style:`, `ci:`, `revert:`). The pipeline enforces commit-per-group: exiting 0 without a new commit is treated as failure.
- If you cannot validate a `- [ ]` task because the required tooling is unavailable (no browser, no UI automation harness, no visual-diff tool, etc.), rewrite the checkbox from `[ ]` to `[-]` and append an observation to `contractor/.observations/<blueprint>/implement.json` describing what tooling would automate the check. Do NOT demote because a task is hard, your test is failing, or the requirement is ambiguous — those still warrant exiting non-zero with a clear message.
- If you cannot complete the group, first prefer demoting unvalidatable tasks to `[-]` as described above; exiting non-zero with a clear error message remains the fallback for genuine blockers (failing tests, ambiguous requirements, incomplete implementations). Do NOT commit a half-finished group.
- If the change has a `scope` (shown in `contractor blueprint show --json`), focus your implementation within that subfolder.


## Before finishing

Write observations to `contractor/.observations/<change>/<phase>.json` — things you noticed but did not act on:
- Code issues you chose not to fix (wrong scope, pre-existing, too large)
- Conventions that should be rules but are not documented
- Task descriptions that did not match reality
- Friction that a tooling or workflow change could eliminate

Write a JSON array of objects: `{ "kind": "code" | "rule" | "process", "summary": "<one line>", "location": "<file:line>", "detail": "<explanation>" }`.
Omit `location` for `process` observations. Write `[]` if you have no observations — do not manufacture items to fill the form.

## Phase Instructions

Implement exactly the assigned task-group, mark its checkboxes, commit, and exit.
The pipeline expands `implement` into one sub-step per incomplete task-group;
each sub-step runs this phase scoped to a single group.

Important:
- All blueprint work MUST happen in a worktree, never on your blueprint's base branch
- Touch only this sub-step's group; leave other groups' checkboxes untouched
- If you encounter issues that require requirement changes, update the requirement artifacts
- Follow the design decisions documented in design.md
- Ensure implementations match the behavioral requirements
