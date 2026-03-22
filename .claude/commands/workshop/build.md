name: Build Change
description: Implement the tasks defined in tasks.md

Work through each task in the implementation checklist, checking boxes as they're completed.

1. Identify which change to build:
   - If the user specifies one (e.g., `/workshop:build add-dark-mode`), use that
   - Otherwise, list directories in `workshop/active/` and pick the one with tasks.md
   - If multiple have tasks.md, ask the user which one

2. Read the full context:
   - `workshop/active/<name>/tasks.md` — the implementation checklist
   - `workshop/active/<name>/intent.md` — motivation and scope
   - `workshop/active/<name>/requirements/` — all req.md files for behavioral specs
   - `workshop/active/<name>/design.md` — technical approach and decisions

3. Work through each unchecked task (`- [ ]`) in order:
   - Implement the task
   - Update the checkbox in `tasks.md` from `- [ ]` to `- [x]`
   - Continue to the next task

4. When all tasks are complete, confirm and suggest:
   - `/workshop:inspect` to verify the implementation
   - `/workshop:ship` to archive and merge specs

Important:
- Update checkboxes as you complete each task, not in bulk at the end
- Follow the design decisions documented in design.md
- Ensure implementations match the behavioral requirements
- If you encounter issues that require spec changes, pause and suggest `/workshop:revise`
- If resuming a partially-completed build, start from the first unchecked task
