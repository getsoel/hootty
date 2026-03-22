name: Draft Artifact
description: Generate the next artifact in the dependency chain

Generate the next artifact for an active unit of work. Call repeatedly to step through: intent → requirements → design → tasks.

1. Identify the active change:
   - List directories in `workshop/active/`
   - If multiple exist, ask the user which one to work on
   - If none exist, suggest `/workshop:bench` first

2. Determine which artifact to generate next by checking what exists:
   - `intent.md` exists? → requirements/ next
   - `requirements/` has at least one `<capability>/req.md`? → design.md next
   - `design.md` exists? → tasks.md next
   - `tasks.md` exists? → all artifacts are done, suggest `/workshop:build`

3. Read all completed upstream artifacts for context.

4. Generate the next artifact following the same guidelines as `/workshop:sketch`:
   - **intent.md**: motivation, scope, approach, impact
   - **requirements/**: delta format, ADDED/MODIFIED/REMOVED, Given/When/Then scenarios, organized by capability
   - **design.md**: technical approach, component structure, data flow, tradeoffs
   - **tasks.md**: ordered checkbox checklist derived from design, grouped by section

5. Write the artifact to disk and confirm what was generated. Show what's next in the chain.

Important:
- Only generate ONE artifact per invocation
- Always read upstream artifacts before generating
- If the user wants to skip ahead, suggest `/workshop:sketch-all`
