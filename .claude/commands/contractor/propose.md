---
name: propose
description: Help the user create a new contractor-driven change.
---

0. **Repo detection**: Check all accessible directories (CWD and any `--add-dir` directories) for a `contractor/` subdirectory. If multiple directories contain `contractor/`, list them and ask the user which repo to target. Then `cd` into the chosen directory so all subsequent commands run in the right context. If only one is found, `cd` there silently.

1. **Worktree check**: Verify whether you are still on a base branch (the branch you started from — typically main/master, or a feature branch you plan to stack on) rather than inside a blueprint worktree (a `contractor/<name>` branch):
   ```
   git rev-parse --abbrev-ref HEAD
   ```
   If not yet inside a worktree (any branch other than `contractor/<name>`), that is expected — contractor will create the worktree when you run `contractor blueprint new <name> --worktree` below. Pass `--base <branch>` if you want to stack the blueprint on a non-default branch. Do NOT run `git worktree add` yourself.

Create a new blueprint with `contractor blueprint new <name> --schema contractor-base --worktree`. Add `--scope <path>` if the user specified a scope. Contractor creates the worktree and prints its path — `cd` there and run every subsequent command from inside it. Never run `git worktree add` yourself.

For each artifact in order (proposal, requirements, design, tasks):
   - Run `contractor blueprint instructions <artifact> --blueprint <name> --json` to get enriched creation instructions
   - Read the instruction, context, and dependency content from the JSON output
   - Generate the artifact following the instructions
   - Write the file to the appropriate location: `contractor/blueprints/<name>/`

After all artifacts are created, run `contractor blueprint status --blueprint <name>` to verify all are done.

Commit the contractor files:
```
git add contractor/blueprints/<name>/ && git commit -m "chore: propose <name>"
```

Then stop. Tell the user the proposal is ready and hand off implementation — either start a fresh Claude Code session inside the worktree, or launch the blueprint from `contractor dashboard`. Do NOT continue into implementation from this session.

End your final response with `/rename contractor/<name>` on its own line (substituting the actual blueprint name) so the user can press enter to label this session with the worktree name.

Important:
- Follow the artifact dependency order
- Read completed artifacts for context when writing later ones
- If the JSON output includes a `scope` field, focus artifacts on that part of the codebase

## Before finishing

Write observations to `contractor/.observations/<change>/<phase>.json` — things you noticed but did not act on:
- Code issues you chose not to fix (wrong scope, pre-existing, too large)
- Conventions that should be rules but are not documented
- Task descriptions that did not match reality
- Friction that a tooling or workflow change could eliminate

Write a JSON array of objects: `{ "kind": "code" | "rule" | "process", "summary": "<one line>", "location": "<file:line>", "detail": "<explanation>" }`.
Omit `location` for `process` observations. Write `[]` if you have no observations — do not manufacture items to fill the form.

## Phase Instructions

Help the user create a new contractor-driven change.

Ask the user what they want to build or change. Get a clear description.
Derive a kebab-case name from their description.

Important:
- All blueprint work MUST happen in a worktree, never on your blueprint's base branch
- Follow the artifact dependency order
- Read completed artifacts for context when writing later ones
- Requirements go in `contractor/blueprints/<name>/requirements/<capability-name>/spec.md`
- Use RFC 2119 keywords (MUST, SHOULD, MAY) in requirements
- Tasks should be ordered by dependency with numbered groups and checkbox items
- When creating a change with `contractor blueprint new`, pass `--scope <path>` if the user specifies a subfolder focus
- Do NOT suggest creating an exploration before creating a proposal — go straight to proposing
- After all artifacts are written, run `contractor blueprint ready <name>` to mark the blueprint ready for implementation, then commit
