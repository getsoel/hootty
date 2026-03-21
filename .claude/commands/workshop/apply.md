---
name: Apply Change
description: Implement tasks from a spec-driven change
---

Implement tasks from the active spec-driven change. Follow these steps:

1. Check for an existing claim:
   ```
   hootty spec current --json
   ```

2. If no claim exists, show available task groups:
   ```
   hootty spec status --json
   ```
   Ask the user which task group to work on, then claim it:
   ```
   hootty spec claim "<task-group-name>"
   ```

3. Read the full `spec/changes/<name>/tasks.md` file to understand the task group.

4. Read the relevant specs and design for context:
   - `spec/changes/<name>/proposal.md`
   - `spec/changes/<name>/specs/` (all spec files)
   - `spec/changes/<name>/design.md`

5. Work through each unchecked task in the claimed group:
   - Implement the task
   - Update the checkbox in `tasks.md` from `- [ ]` to `- [x]`
   - Continue to the next task

6. When all tasks in the group are complete, release the claim:
   ```
   hootty spec release
   ```

7. If there are more task groups to do, ask if the user wants to claim another.

Important:
- Only work on tasks in the claimed group
- Update checkboxes as you complete each task, not in bulk at the end
- If you encounter issues that require spec changes, update the spec artifacts
- Follow the design decisions documented in design.md
- Ensure implementations match the behavioral specs
