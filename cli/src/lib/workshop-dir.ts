import { existsSync, readFileSync } from "fs";
import { join, resolve, dirname } from "path";
import { parseYaml } from "./yaml";

const WORKSHOP_DIR = "workshop";
const HOOTTY_DIR = ".hootty";

export interface WorkshopConfig {
  schema?: string;
  context?: string;
  rules?: Record<string, string[]>;
}

export interface WorkshopPaths {
  /** Project root (parent of workshop/) */
  root: string;
  /** workshop/ directory */
  workshop: string;
  /** workshop/config.yaml */
  config: string;
  /** workshop/specs/ (source of truth) */
  specs: string;
  /** workshop/changes/ */
  changes: string;
  /** workshop/archive/ */
  archive: string;
  /** .hootty/ */
  hootty: string;
  /** .hootty/claims/ */
  claims: string;
}

/** Walk up from cwd to find workshop/ directory. */
export function findWorkshopRoot(from?: string): WorkshopPaths | null {
  let dir = resolve(from || process.cwd());

  for (let i = 0; i < 50; i++) {
    const workshopPath = join(dir, WORKSHOP_DIR);
    if (existsSync(workshopPath)) {
      return buildPaths(dir);
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  return null;
}

/** Build paths for a known project root. */
export function buildPaths(root: string): WorkshopPaths {
  const workshop = join(root, WORKSHOP_DIR);
  return {
    root,
    workshop,
    config: join(workshop, "config.yaml"),
    specs: join(workshop, "specs"),
    changes: join(workshop, "changes"),
    archive: join(workshop, "archive"),
    hootty: join(root, HOOTTY_DIR),
    claims: join(root, HOOTTY_DIR, "claims"),
  };
}

/** Require workshop/ to exist, exit with error if not. */
export function requireWorkshopDir(from?: string): WorkshopPaths {
  const paths = findWorkshopRoot(from);
  if (!paths) {
    console.error(
      "error: No workshop/ directory found. Run `hootty workshop init` first."
    );
    process.exit(1);
  }
  return paths;
}

/** Read and parse workshop/config.yaml. */
export function readConfig(paths: WorkshopPaths): WorkshopConfig {
  if (!existsSync(paths.config)) return {};
  const content = readFileSync(paths.config, "utf-8");
  const raw = parseYaml(content);

  const config: WorkshopConfig = {
    schema: raw.schema,
    context: raw.context,
  };

  // Parse rules (simple format: key is artifact id, value is newline-separated rules)
  // For now, rules are embedded in the context field. Parsing structured rules
  // can be added later if config.yaml grows more complex.

  return config;
}

/** Get path to a specific change directory. */
export function changePath(paths: WorkshopPaths, name: string): string {
  return join(paths.changes, name);
}

/** Get path to an archived change directory. */
export function archivePath(paths: WorkshopPaths, name: string): string {
  return join(paths.archive, name);
}
