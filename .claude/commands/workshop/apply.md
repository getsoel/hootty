---
name: Apply Change
description: Implement tasks from a workshop-driven change
---

Implement tasks from the active workshop-driven change. Follow these steps:

1. Check for an existing claim:
   ```
   workshop current --json
   ```

2. If no claim exists, show available task groups:
   ```
   workshop status --json
   ```
   Ask the user which task group to work on, then claim it:
   ```
   workshop claim "<task-group-name>"
   ```

3. Read the full `workshop/changes/<name>/tasks.md` file to understand the task group.

4. Read the relevant specs and design for context:
   - `workshop/changes/<name>/proposal.md`
   - `workshop/changes/<name>/specs/` (all spec files)
   - `workshop/changes/<name>/design.md`

5. Work through each unchecked task in the claimed group:
   - Implement the task
   - Update the checkbox in `tasks.md` from `- [ ]` to `- [x]`
   - Continue to the next task

6. When all tasks in the group are complete, release the claim:
   ```
   workshop release
   ```

7. If there are more task groups to do, ask if the user wants to claim another.

Important:
- Only work on tasks in the claimed group
- Update checkboxes as you complete each task, not in bulk at the end
- If you encounter issues that require spec changes, update the spec artifacts
- Follow the design decisions documented in design.md
- Ensure implementations match the behavioral specs
- If the change has a `scope` (shown in `workshop current --json`), focus implementation within that subfolder
