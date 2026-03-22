name: Workshop Tour
description: Guided walkthrough of the Workshop workflow using your actual codebase

Walk the user through the complete Workshop workflow, explaining concepts with examples from their codebase.

1. **Introduction**: Explain Workshop's philosophy:
   - Sketch before you build
   - Revise as you learn
   - Ship when it's ready
   - Works for features, fixes, and refactors

2. **Folder structure**: Show the workshop layout:
   - `workshop/active/` — work in progress (the workbench)
   - `workshop/specs/` — canonical specifications (source of truth)
   - `workshop/archive/` — shipped work (historical record)

3. **Artifacts**: Explain the four artifacts and their dependency chain:
   - `intent.md` — why (motivation, scope, approach)
   - `requirements/<capability>/req.md` — what (delta format, scenarios)
   - `design.md` — how (technical approach, tradeoffs)
   - `tasks.md` — work (implementation checklist)

4. **The fast path**: Walk through the quick workflow:
   - `/workshop:sketch` → generates all four artifacts
   - `/workshop:build` → implements the tasks
   - `/workshop:ship` → archives and merges specs

5. **The deliberate path**: Show step-by-step control:
   - `/workshop:bench` → creates the folder
   - `/workshop:draft` → generates one artifact at a time
   - `/workshop:revise` → rework without advancing

6. **Check current state**: Run `/workshop:status` equivalent to show what's on the bench right now.

7. **Offer to start**: Ask if they'd like to try sketching a change.

Important:
- Use examples from the user's actual codebase and tech stack
- Keep it conversational, not lecture-style
- Adapt the depth based on user engagement
- This is read-only — do NOT create any files unless the user asks to start
