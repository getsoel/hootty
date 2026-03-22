name: Ship All Changes
description: Ship multiple completed units of work at once

Batch archive all completed changes, merging specs and detecting conflicts.

1. List all directories in `workshop/active/`.

2. For each change, check completion:
   - All artifacts exist (intent.md, requirements/, design.md, tasks.md)
   - All tasks in tasks.md are checked off
   - Separate into "ready to ship" and "not ready"

3. Show the summary:
   - Ready to ship: list with task counts
   - Not ready: list with what's missing/incomplete

4. If no changes are ready, explain what needs to be done.

5. If ready changes exist:
   - Check for spec merge conflicts between changes (e.g., two changes modifying the same capability's requirements)
   - Warn about any conflicts and ask how to resolve
   - Confirm the list of changes to ship

6. Ship each ready change in order (same process as `/workshop:ship`):
   - Merge requirements into `workshop/specs/`
   - Move to `workshop/archive/YYYY-MM-DD-<name>/`
   - Clean up stale tracking

7. Report results for each change shipped.

Important:
- Process changes one at a time to handle merge ordering
- If a merge conflict arises mid-batch, pause and ask the user
- Use today's date for all archive prefixes
