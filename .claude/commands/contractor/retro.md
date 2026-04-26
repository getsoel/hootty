---
name: Retrospective
description: Review and apply pending observations from agent sessions
---

Address observations captured by agent sessions during implement, review, and propose phases.

0. **Repo detection**: Check all accessible directories (CWD and any `--add-dir` directories) for a `contractor/` subdirectory. If multiple directories contain `contractor/`, list them and ask the user which repo to target. Then `cd` into the chosen directory so all subsequent commands run in the right context. If only one is found, `cd` there silently.

1. Read all `.json` files in `contractor/.observations/` (each subdirectory is a change name, each file is a phase). If no non-empty files exist, report "No pending observations." and stop.

2. Group observations by source change name. Present a summary table:

   | # | Kind | Summary | Location | Source |
   |---|------|---------|----------|--------|

   Include sequential numbers for selection.

3. Ask the user which observations to address. The user can select individual items (by number), all, or none.

4. For each selected observation:
   - **`code`**: Read the referenced file, assess whether the issue still exists, and fix it directly. If the code has changed such that the issue no longer applies, note it and move on.
   - **`rule`**: Update `CLAUDE.md` (if the rule fires on every task/commit/command) or extend the matching `context/<topic>.md` topic doc (if it's scoped to a surface — pipeline, blueprints, code layout, etc.). This repo does not have a `.claude/rules/` directory.
   - **`process`**: Note and dismiss — no action beyond removing from the file.

5. Clean up the observation files:
   - Remove addressed and dismissed items from their JSON file
   - Delete the JSON file entirely if all its items have been addressed
   - Delete the change subdirectory if all its files have been removed

6. If any code fixes or rule updates were made, offer to commit the changes. Use a conventional commit message (e.g. `fix:`, `refactor:`, `docs:`) that describes the actual work done.

Important:
- Do NOT auto-apply observations without user confirmation
- Always show the full observation detail before asking for confirmation
- If a code fix requires a large refactor, confirm the approach with the user
- Handle missing files gracefully (the code may have been moved or deleted)