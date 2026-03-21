---
name: Propose Change
description: Create a new spec-driven change with proposal, specs, design, and tasks
---

Help the user create a new spec-driven change. Follow these steps:

1. Ask the user what they want to build or change. Get a clear description.

2. Derive a kebab-case name from their description and create the change:
   ```
   hootty spec new <name>
   ```

3. For each artifact in order (proposal, specs, design, tasks):
   - Run `hootty spec instructions <artifact> --change <name> --json` to get enriched creation instructions
   - Read the instruction, context, and dependency content from the JSON output
   - Generate the artifact following the instructions
   - Write the file to the appropriate location in `spec/changes/<name>/`

4. After all artifacts are created, run `hootty spec status --change <name>` to verify all are done.

5. Show the user the final status and suggest they run `/spec:apply` to start implementation.

Important:
- Follow the artifact dependency order: proposal first, then specs and design (can be done in either order), then tasks last
- Read completed artifacts for context when writing later ones
- Specs go in `spec/changes/<name>/specs/<capability-name>/spec.md`
- Use RFC 2119 keywords (MUST, SHOULD, MAY) in specs
- Tasks should be ordered by dependency with numbered groups and checkbox items
