---
name: Archive Change
description: Archive a completed workshop-driven change
---

Archive a completed change, merging its specs into the source of truth.

1. Run `workshop list` to show available changes.

2. Run `workshop status --change <name>` to verify completion:
   - All artifacts should be done
   - All tasks should be checked off

3. If tasks are incomplete, ask the user if they want to proceed anyway.

4. Archive the change:
   ```
   workshop archive <name> --yes
   ```

5. Confirm the archive was successful and show what was merged into `workshop/specs/`.
