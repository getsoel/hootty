---
name: rebase
description: After rebasing the worktree onto main, review and update blueprint artifacts
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


Review and update blueprint artifacts after rebasing onto main.

## 1. Discover capability overlap

List the directories under `contractor/requirements/` (global specs) and
`contractor/blueprints/<name>/requirements/` (blueprint delta specs). Find
capability names that appear in both locations — these are the capabilities
where the blueprint's assumptions may have drifted.

If no overlapping capabilities exist, report that and stop — no changes needed.

## 2. Read pre-rebase context

Read `contractor/.state/rebase-diff.txt` and `contractor/.state/rebase-log.txt`
for context about what changed on main since the blueprint branched.

If the context files are missing, fall back to `git log` and `git diff` to
determine what changed.

## 3. Analyze overlapping specs

For each overlapping capability:
1. Read the global spec at `contractor/requirements/<capability>/spec.md`
2. Read the blueprint's delta spec at `contractor/blueprints/<name>/requirements/<capability>/spec.md`
3. Determine if the delta spec still makes sense given the updated global spec

## 4. Update blueprint artifacts

Based on your analysis:

**design.md** — Revise sections whose assumptions changed due to landed blueprints.

**tasks.md** — Adjust pending task approaches if code was restructured on main.
Annotate completed tasks that touch changed capabilities with a warning
(e.g. "⚠ verify after rebase") but do NOT un-check completed tasks.
Add new tasks if rework is needed.

**Delta specs** — If a delta spec conflicts with the new global spec (e.g.
modifying a requirement that was renamed or removed), update or remove it.
If the global spec now covers what the delta was adding, flag it as
potentially unnecessary.

## 5. Commit updated artifacts

If any artifacts were updated, commit with:
```
git add contractor/blueprints/<name>/ && git commit -m "chore: update blueprint artifacts after rebase onto main"
```

Only include blueprint artifact files (design.md, tasks.md, requirement specs)
in the commit — no source code changes.

After rebasing the worktree onto main, review and update blueprint artifacts
to reflect any changes that landed on main since the blueprint branched.
Use the capability overlap between global requirements and the blueprint's
delta specs to identify which artifacts may be stale.


## Before finishing

Write observations to `contractor/.observations/<change>/<phase>.json` — things you noticed but did not act on:
- Code issues you chose not to fix (wrong scope, pre-existing, too large)
- Conventions that should be rules but are not documented
- Task descriptions that did not match reality
- Friction that a tooling or workflow change could eliminate

Write a JSON array of objects: `{ "kind": "code" | "rule" | "process", "summary": "<one line>", "location": "<file:line>", "detail": "<explanation>" }`.
Omit `location` for `process` observations. Write `[]` if you have no observations — do not manufacture items to fill the form.

## Phase Instructions

After rebasing the worktree onto main, review and update blueprint artifacts
to reflect any changes that landed on main since the blueprint branched.
Use the capability overlap between global requirements and the blueprint's
delta specs to identify which artifacts may be stale.
