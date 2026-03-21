import { existsSync, readdirSync } from "fs";
import { join } from "path";

export type ArtifactId = "proposal" | "specs" | "design" | "tasks";
export type ArtifactState = "blocked" | "ready" | "done";

export interface ArtifactInfo {
  id: ArtifactId;
  state: ArtifactState;
  file: string;
  description: string;
  requires: ArtifactId[];
}

interface ArtifactDef {
  id: ArtifactId;
  file: string;
  description: string;
  requires: ArtifactId[];
}

/** Hardcoded spec-driven DAG. */
const ARTIFACT_DEFS: ArtifactDef[] = [
  {
    id: "proposal",
    file: "proposal.md",
    description: "Why this change exists and what it does",
    requires: [],
  },
  {
    id: "specs",
    file: "specs/*/spec.md",
    description: "Behavioral specifications for new/modified capabilities",
    requires: ["proposal"],
  },
  {
    id: "design",
    file: "design.md",
    description: "Technical design decisions and architecture",
    requires: ["proposal"],
  },
  {
    id: "tasks",
    file: "tasks.md",
    description: "Implementation checklist with task groups",
    requires: ["specs", "design"],
  },
];

/** Check if an artifact's generated file(s) exist. */
function isArtifactDone(changePath: string, def: ArtifactDef): boolean {
  if (def.file.includes("*")) {
    // Glob pattern: specs/*/spec.md — check if any spec.md exists
    const specsDir = join(changePath, "specs");
    if (!existsSync(specsDir)) return false;
    try {
      const dirs = readdirSync(specsDir, { withFileTypes: true });
      return dirs.some(
        (d) => d.isDirectory() && existsSync(join(specsDir, d.name, "spec.md"))
      );
    } catch {
      return false;
    }
  }
  return existsSync(join(changePath, def.file));
}

/** Resolve artifact states for a change directory. */
export function resolveArtifacts(changePath: string): ArtifactInfo[] {
  const completed = new Set<ArtifactId>();

  // First pass: determine which artifacts are done
  for (const def of ARTIFACT_DEFS) {
    if (isArtifactDone(changePath, def)) {
      completed.add(def.id);
    }
  }

  // Second pass: compute states
  return ARTIFACT_DEFS.map((def) => {
    let state: ArtifactState;
    if (completed.has(def.id)) {
      state = "done";
    } else if (def.requires.every((r) => completed.has(r))) {
      state = "ready";
    } else {
      state = "blocked";
    }
    return { ...def, state };
  });
}

/** Get the next artifacts that can be created (state === "ready"). */
export function getNextArtifacts(changePath: string): ArtifactInfo[] {
  return resolveArtifacts(changePath).filter((a) => a.state === "ready");
}

/** Check if all artifacts are done. */
export function allArtifactsDone(changePath: string): boolean {
  return resolveArtifacts(changePath).every((a) => a.state === "done");
}

/** Get a specific artifact definition. */
export function getArtifactDef(id: string): ArtifactDef | undefined {
  return ARTIFACT_DEFS.find((d) => d.id === id);
}

export const ALL_ARTIFACT_IDS: ArtifactId[] = ARTIFACT_DEFS.map((d) => d.id);
