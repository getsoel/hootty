name: Sketch All Remaining
description: Generate all remaining artifacts at once

Fill in all missing artifacts for an active unit of work. Useful when you've drafted some manually and want to complete the rest.

1. Identify the active change:
   - List directories in `workshop/active/`
   - If multiple exist, ask the user which one to work on
   - If none exist, suggest `/workshop:bench` first

2. Check which artifacts already exist:
   - `intent.md`
   - `requirements/<capability>/req.md` (any subdirectory)
   - `design.md`
   - `tasks.md`

3. Read all existing artifacts for context.

4. Generate each missing artifact in dependency order (intent → requirements → design → tasks), reading each newly created artifact before generating the next.

5. Confirm all artifacts are now complete and suggest `/workshop:build`.

Important:
- Skip artifacts that already exist — don't overwrite
- Follow the dependency chain: earlier artifacts inform later ones
- If intent.md doesn't exist and nothing else does, this behaves like `/workshop:sketch`
