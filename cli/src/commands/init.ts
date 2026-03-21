import { existsSync, mkdirSync, writeFileSync, readFileSync } from "fs";
import { join, resolve } from "path";
import { buildPaths } from "../lib/spec-dir";
import { printSuccess, printError } from "../lib/output";

const DEFAULT_CONFIG = `schema: spec-driven

# Project context (optional)
# Shown to AI when creating artifacts. Add your tech stack, conventions, etc.
# context: |
#   Tech stack: TypeScript, React, Node.js
#   We use conventional commits

# Per-artifact rules (optional)
# rules:
#   proposal:
#     - Keep proposals under 500 words
#   tasks:
#     - Break tasks into chunks of max 2 hours
`;

const COMMAND_PROPOSE = `---
name: Propose Change
description: Create a new spec-driven change with proposal, specs, design, and tasks
---

Help the user create a new spec-driven change. Follow these steps:

1. Ask the user what they want to build or change. Get a clear description.

2. Derive a kebab-case name from their description and create the change:
   \`\`\`
   hootty spec new <name>
   \`\`\`

3. For each artifact in order (proposal, specs, design, tasks):
   - Run \`hootty spec instructions <artifact> --change <name> --json\` to get enriched creation instructions
   - Read the instruction, context, and dependency content from the JSON output
   - Generate the artifact following the instructions
   - Write the file to the appropriate location in \`spec/changes/<name>/\`

4. After all artifacts are created, run \`hootty spec status --change <name>\` to verify all are done.

5. Show the user the final status and suggest they run \`/spec:apply\` to start implementation.

Important:
- Follow the artifact dependency order: proposal first, then specs and design (can be done in either order), then tasks last
- Read completed artifacts for context when writing later ones
- Specs go in \`spec/changes/<name>/specs/<capability-name>/spec.md\`
- Use RFC 2119 keywords (MUST, SHOULD, MAY) in specs
- Tasks should be ordered by dependency with numbered groups and checkbox items
`;

const COMMAND_EXPLORE = `---
name: Explore
description: Investigate and explore without implementing
---

Help the user explore and investigate their codebase or spec state. This is a free-form mode for thinking, diagramming, and understanding.

1. Run \`hootty spec status\` to show current spec state.

2. Based on the user's question, explore the codebase, read specs, and investigate.

3. Share your findings as conversation — do NOT implement anything or modify code.

Rules:
- Do NOT modify any source code files
- Do NOT update task checkboxes
- Do NOT create or modify spec artifacts unless the user explicitly asks
- Focus on understanding, analysis, and discussion
- You may read any files, search the codebase, and analyze architecture
`;

const COMMAND_APPLY = `---
name: Apply Change
description: Implement tasks from a spec-driven change
---

Implement tasks from the active spec-driven change. Follow these steps:

1. Check for an existing claim:
   \`\`\`
   hootty spec current --json
   \`\`\`

2. If no claim exists, show available task groups:
   \`\`\`
   hootty spec status --json
   \`\`\`
   Ask the user which task group to work on, then claim it:
   \`\`\`
   hootty spec claim "<task-group-name>"
   \`\`\`

3. Read the full \`spec/changes/<name>/tasks.md\` file to understand the task group.

4. Read the relevant specs and design for context:
   - \`spec/changes/<name>/proposal.md\`
   - \`spec/changes/<name>/specs/\` (all spec files)
   - \`spec/changes/<name>/design.md\`

5. Work through each unchecked task in the claimed group:
   - Implement the task
   - Update the checkbox in \`tasks.md\` from \`- [ ]\` to \`- [x]\`
   - Continue to the next task

6. When all tasks in the group are complete, release the claim:
   \`\`\`
   hootty spec release
   \`\`\`

7. If there are more task groups to do, ask if the user wants to claim another.

Important:
- Only work on tasks in the claimed group
- Update checkboxes as you complete each task, not in bulk at the end
- If you encounter issues that require spec changes, update the spec artifacts
- Follow the design decisions documented in design.md
- Ensure implementations match the behavioral specs
`;

const COMMAND_ARCHIVE = `---
name: Archive Change
description: Archive a completed spec-driven change
---

Archive a completed change, merging its specs into the source of truth.

1. Run \`hootty spec list\` to show available changes.

2. Run \`hootty spec status --change <name>\` to verify completion:
   - All artifacts should be done
   - All tasks should be checked off

3. If tasks are incomplete, ask the user if they want to proceed anyway.

4. Archive the change:
   \`\`\`
   hootty spec archive <name> --yes
   \`\`\`

5. Confirm the archive was successful and show what was merged into \`spec/specs/\`.
`;

const COMMANDS: Record<string, string> = {
  "propose.md": COMMAND_PROPOSE,
  "explore.md": COMMAND_EXPLORE,
  "apply.md": COMMAND_APPLY,
  "archive.md": COMMAND_ARCHIVE,
};

export async function runInit(): Promise<void> {
  const root = resolve(process.cwd());
  const paths = buildPaths(root);

  if (existsSync(paths.spec)) {
    printError("spec/ directory already exists.");
    process.exit(1);
  }

  // Create spec/ directory structure
  mkdirSync(paths.specs, { recursive: true });
  mkdirSync(paths.changes, { recursive: true });
  mkdirSync(paths.archive, { recursive: true });
  writeFileSync(paths.config, DEFAULT_CONFIG);

  // Write Claude Code slash commands
  const commandsDir = join(root, ".claude", "commands", "spec");
  mkdirSync(commandsDir, { recursive: true });
  for (const [filename, content] of Object.entries(COMMANDS)) {
    const dest = join(commandsDir, filename);
    if (!existsSync(dest)) {
      writeFileSync(dest, content);
    }
  }

  // Ensure .hootty/ is in .gitignore
  const gitignorePath = join(root, ".gitignore");
  if (existsSync(gitignorePath)) {
    const content = readFileSync(gitignorePath, "utf-8");
    if (!content.includes(".hootty/")) {
      writeFileSync(gitignorePath, content.trimEnd() + "\n.hootty/\n");
    }
  } else {
    writeFileSync(gitignorePath, ".hootty/\n");
  }

  printSuccess(`Initialized spec/ in ${root}`);
  printSuccess("  spec/config.yaml                — project configuration");
  printSuccess("  spec/specs/                     — accumulated specs");
  printSuccess("  spec/changes/                   — active changes");
  printSuccess("  spec/archive/                   — archived changes");
  printSuccess("  .claude/commands/spec/           — /spec:* slash commands");
}
