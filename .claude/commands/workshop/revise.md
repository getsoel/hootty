name: Revise Artifact
description: Update an existing artifact without advancing to the next one

Rework a specific artifact based on user feedback or new information, without generating downstream artifacts.

1. Determine which artifact to revise:
   - If the user specifies one (e.g., `/workshop:revise intent.md`), use that
   - Otherwise, list available artifacts for the active change and ask

2. Identify the active change:
   - List directories in `workshop/active/`
   - If multiple exist, ask which one

3. Read the current artifact content and its upstream dependencies for context.

4. Discuss changes with the user, then update the artifact file in place.

5. After revising, check if downstream artifacts exist and may be stale:
   - intent.md changed → requirements/, design.md, tasks.md may be stale
   - requirements/ changed → design.md, tasks.md may be stale
   - design.md changed → tasks.md may be stale
   - tasks.md changed → no downstream artifacts

6. If stale downstream artifacts exist, ask the user if they want to regenerate them.

Important:
- Only modify the specified artifact — do NOT advance to the next one
- Preserve the user's intent — they revised for a reason
- If regenerating downstream, use the updated artifact as context
- The user can also edit artifacts directly in their editor and use this command to review consistency
