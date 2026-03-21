import { existsSync, readFileSync, readdirSync } from "fs";
import { join } from "path";
import { requireSpecDir, readConfig, changePath } from "../lib/spec-dir";
import { resolveChange } from "../lib/changes";
import {
  getArtifactDef,
  resolveArtifacts,
  ALL_ARTIFACT_IDS,
} from "../lib/artifacts";
import { printJson, printError } from "../lib/output";

interface InstructionsOpts {
  artifactId: string;
  change?: string;
  json: boolean;
}

/** Read content of completed dependency artifacts for context. */
function readDependencyContent(
  changeDir: string,
  requires: string[]
): Record<string, string> {
  const content: Record<string, string> = {};
  for (const depId of requires) {
    const def = getArtifactDef(depId);
    if (!def) continue;

    if (depId === "specs") {
      // Read all spec files
      const specsDir = join(changeDir, "specs");
      if (existsSync(specsDir)) {
        const dirs = readdirSync(specsDir, { withFileTypes: true });
        const specContents: string[] = [];
        for (const d of dirs) {
          if (!d.isDirectory()) continue;
          const specFile = join(specsDir, d.name, "spec.md");
          if (existsSync(specFile)) {
            specContents.push(
              `### ${d.name}\n${readFileSync(specFile, "utf-8")}`
            );
          }
        }
        if (specContents.length > 0) {
          content[depId] = specContents.join("\n\n");
        }
      }
    } else {
      const filePath = join(changeDir, def.file);
      if (existsSync(filePath)) {
        content[depId] = readFileSync(filePath, "utf-8");
      }
    }
  }
  return content;
}

/** Read accumulated specs from spec/specs/ for context. */
function readAccumulatedSpecs(specsDir: string): string | null {
  if (!existsSync(specsDir)) return null;

  const dirs = readdirSync(specsDir, { withFileTypes: true });
  const sections: string[] = [];

  for (const d of dirs) {
    if (!d.isDirectory()) continue;
    const specFile = join(specsDir, d.name, "spec.md");
    if (existsSync(specFile)) {
      sections.push(`### ${d.name}\n${readFileSync(specFile, "utf-8")}`);
    }
  }

  return sections.length > 0 ? sections.join("\n\n") : null;
}

const ARTIFACT_INSTRUCTIONS: Record<string, string> = {
  proposal: `Write a proposal for this change. Include:

## Why
Explain the motivation — what problem exists and why it needs solving.

## What Changes
Bullet list of concrete changes being made.

## Capabilities
### New Capabilities
List each new capability with a short description.

### Modified Capabilities
List changes to existing capabilities, or "(none)" if no existing specs are affected.

## Impact
Note impact on database, routes, dependencies, API, or other systems.`,

  specs: `Write behavioral specifications for the new/modified capabilities described in the proposal.

Create one spec file per capability in specs/<capability-name>/spec.md.

Each spec should define behavior contracts using RFC 2119 keywords (MUST, SHOULD, MAY):
- What the system MUST do (required behavior)
- What it SHOULD do (recommended behavior)
- What it MAY do (optional behavior)

Focus on observable behavior, not implementation details.

If modifying existing capabilities, use delta markers:
- ADDED: new requirements
- MODIFIED: changed requirements (show before → after)
- REMOVED: deleted requirements`,

  design: `Write a technical design document. Include:

## Approach
Describe the implementation strategy and key technical decisions.

## Key Decisions
List important architectural choices with rationale.

## Dependencies
Note any new dependencies or system requirements.

Keep it concise — focus on decisions that affect the codebase, not obvious implementation details.`,

  tasks: `Write an implementation checklist based on the specs and design.

Format as numbered task groups with checkbox items:

## 1. Group Name

- [ ] 1.1 Task description
- [ ] 1.2 Task description

## 2. Another Group

- [ ] 2.1 Task description

Guidelines:
- Order groups by dependency (do first things first)
- Each task should be completable in one focused session
- Be specific — reference files, functions, routes by name where possible
- Include testing tasks alongside implementation tasks`,
};

export async function runInstructions(opts: InstructionsOpts): Promise<void> {
  const paths = requireSpecDir();

  if (!ALL_ARTIFACT_IDS.includes(opts.artifactId as any)) {
    printError(
      `Unknown artifact: "${opts.artifactId}". Valid: ${ALL_ARTIFACT_IDS.join(", ")}`
    );
    process.exit(1);
  }

  const changeName = resolveChange(paths.changes, opts.change);
  const changeDir = changePath(paths, changeName);

  if (!existsSync(changeDir)) {
    printError(`Change "${changeName}" not found.`);
    process.exit(1);
  }

  const def = getArtifactDef(opts.artifactId)!;
  const artifacts = resolveArtifacts(changeDir);
  const thisArtifact = artifacts.find((a) => a.id === opts.artifactId)!;
  const config = readConfig(paths);

  // Build enriched instructions
  const instruction = ARTIFACT_INSTRUCTIONS[opts.artifactId] || "";
  const dependencyContent = readDependencyContent(changeDir, def.requires);
  const accumulatedSpecs = readAccumulatedSpecs(paths.specs);

  const result = {
    artifact: opts.artifactId,
    change: changeName,
    state: thisArtifact.state,
    file: def.file,
    instruction,
    context: config.context || null,
    dependencies: dependencyContent,
    accumulatedSpecs,
  };

  if (opts.json) {
    printJson(result);
    return;
  }

  // Human-readable output
  console.log(`\nArtifact: ${opts.artifactId} (${thisArtifact.state})`);
  console.log(`Change: ${changeName}`);
  console.log(`File: ${def.file}`);
  console.log(`\n--- Instructions ---\n`);
  console.log(instruction);

  if (config.context) {
    console.log(`\n--- Project Context ---\n`);
    console.log(config.context);
  }

  if (Object.keys(dependencyContent).length > 0) {
    console.log(`\n--- Completed Dependencies ---\n`);
    for (const [id, content] of Object.entries(dependencyContent)) {
      console.log(`## ${id}\n${content}\n`);
    }
  }

  if (accumulatedSpecs) {
    console.log(`\n--- Existing Specs ---\n`);
    console.log(accumulatedSpecs);
  }
}
