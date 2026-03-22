name: Ship Change
description: Archive completed work and merge requirements into specs

The finished piece leaves the workshop — archive and merge into the canonical spec.

1. Identify which change to ship:
   - If the user specifies one, use that
   - Otherwise, list directories in `workshop/active/`
   - If multiple exist, ask which one

2. Verify readiness:
   - Check that all artifacts exist (intent.md, requirements/, design.md, tasks.md)
   - Check that all tasks in tasks.md are checked off
   - If incomplete, warn the user and ask if they want to proceed anyway

3. Merge requirements into canonical specs:
   - For each `workshop/active/<name>/requirements/<capability>/req.md`:
     - If `workshop/specs/<capability>/spec.md` exists, merge the delta (ADDED/MODIFIED/REMOVED) into the existing spec
     - If it doesn't exist, create `workshop/specs/<capability>/spec.md` from the requirements
   - Create `workshop/specs/` and capability directories as needed

4. Archive the change:
   - Create date-prefixed archive directory:
     ```
     mkdir -p workshop/archive/YYYY-MM-DD-<name>
     ```
   - Move all contents from `workshop/active/<name>/` to the archive directory
   - Remove the now-empty `workshop/active/<name>/` directory

5. Clean up any `.hootty/stale/<name>.yaml` file if it exists.

6. Confirm the ship was successful:
   - Show what was merged into specs
   - Show the archive location
   - Note if the bench is now clear

Important:
- Use today's date (YYYY-MM-DD) for the archive prefix
- Merge requirements carefully — ADDED sections become new requirements, MODIFIED update existing ones, REMOVED delete them
- Preserve existing spec content that isn't affected by the delta
- If merging would conflict with another in-flight change's requirements, warn the user
