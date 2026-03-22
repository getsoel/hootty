name: Workshop Status
description: Show what's on the bench — active work, artifact states, and staleness

Display the current state of the workshop.

1. Check if `workshop/` directory exists. If not, explain that the workshop hasn't been initialized.

2. List active work from `workshop/active/`:
   - For each change directory, check which artifacts exist:
     - `intent.md` — exists or missing
     - `requirements/` — list capability subdirectories with req.md
     - `design.md` — exists or missing
     - `tasks.md` — exists or missing; if exists, show progress (checked/total)

3. List archived work from `workshop/archive/` (if any):
   - Show count and names (date-prefixed)

4. List canonical specs from `workshop/specs/` (if any):
   - Show capability directories

5. Format output as a clear summary:
   ```
   Workshop Status
   ═══════════════

   Active (2):
     add-dark-mode
       ✓ intent.md
       ✓ requirements/ui/req.md
       ○ design.md (ready)
       ◌ tasks.md (blocked)

     fix-login-redirect
       ✓ intent.md
       ✓ requirements/auth/req.md
       ✓ design.md
       ✓ tasks.md [3/7]

   Archive (1):
     2026-03-20-add-search

   Specs:
     ui/, auth/
   ```

Important:
- This is read-only — do NOT modify any files
- Show task progress when tasks.md exists
- Mark stale artifacts if .hootty/stale/ tracking exists
