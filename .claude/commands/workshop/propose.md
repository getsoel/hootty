---
name: Propose Change
description: Create a new workshop-driven change with proposal, specs, design, and tasks
---

Help the user create a new workshop-driven change. Follow these steps:

1. Ask the user what they want to build or change. Get a clear description.

2. Derive a kebab-case name from their description and create the change:
   ```
   workshop new <name>
   ```

3. Claim the change for this session:
   ```
   workshop claim --change <name>
   ```

4. For each artifact in order (proposal, specs, design, tasks):
   - Run `workshop instructions <artifact> --change <name> --json` to get enriched creation instructions
   - Read the instruction, context, and dependency content from the JSON output
   - Generate the artifact following the instructions
   - Write the file to the appropriate location in `workshop/changes/<name>/`

5. After all artifacts are created, run `workshop status --change <name>` to verify all are done.

6. Show the user the final status and suggest they run `/workshop:apply` to start implementation.

Important:
- Follow the artifact dependency order: proposal first, then specs and design (can be done in either order), then tasks last
- Read completed artifacts for context when writing later ones
- Specs go in `workshop/changes/<name>/specs/<capability-name>/spec.md`
- Use RFC 2119 keywords (MUST, SHOULD, MAY) in specs
- Tasks should be ordered by dependency with numbered groups and checkbox items
- If the JSON output includes a `scope` field, the change is scoped to that subfolder — focus proposals, specs, design, and tasks on that part of the codebase
- When creating a change with `workshop new`, pass `--scope <path>` if the user specifies a subfolder focus
