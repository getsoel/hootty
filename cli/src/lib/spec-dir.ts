import { existsSync, readFileSync } from "fs";
import { join, resolve, dirname } from "path";
import { parseYaml } from "./yaml";

const SPEC_DIR = "spec";
const HOOTTY_DIR = ".hootty";

export interface SpecConfig {
  schema?: string;
  context?: string;
  rules?: Record<string, string[]>;
}

export interface SpecPaths {
  /** Project root (parent of spec/) */
  root: string;
  /** spec/ directory */
  spec: string;
  /** spec/config.yaml */
  config: string;
  /** spec/specs/ (source of truth) */
  specs: string;
  /** spec/changes/ */
  changes: string;
  /** spec/archive/ */
  archive: string;
  /** .hootty/ */
  hootty: string;
  /** .hootty/claims/ */
  claims: string;
}

/** Walk up from cwd to find spec/ directory. */
export function findSpecRoot(from?: string): SpecPaths | null {
  let dir = resolve(from || process.cwd());

  for (let i = 0; i < 50; i++) {
    const specPath = join(dir, SPEC_DIR);
    if (existsSync(specPath)) {
      return buildPaths(dir);
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  return null;
}

/** Build paths for a known project root. */
export function buildPaths(root: string): SpecPaths {
  const spec = join(root, SPEC_DIR);
  return {
    root,
    spec,
    config: join(spec, "config.yaml"),
    specs: join(spec, "specs"),
    changes: join(spec, "changes"),
    archive: join(spec, "archive"),
    hootty: join(root, HOOTTY_DIR),
    claims: join(root, HOOTTY_DIR, "claims"),
  };
}

/** Require spec/ to exist, exit with error if not. */
export function requireSpecDir(from?: string): SpecPaths {
  const paths = findSpecRoot(from);
  if (!paths) {
    console.error(
      "error: No spec/ directory found. Run `hootty spec init` first."
    );
    process.exit(1);
  }
  return paths;
}

/** Read and parse spec/config.yaml. */
export function readConfig(paths: SpecPaths): SpecConfig {
  if (!existsSync(paths.config)) return {};
  const content = readFileSync(paths.config, "utf-8");
  const raw = parseYaml(content);

  const config: SpecConfig = {
    schema: raw.schema,
    context: raw.context,
  };

  // Parse rules (simple format: key is artifact id, value is newline-separated rules)
  // For now, rules are embedded in the context field. Parsing structured rules
  // can be added later if config.yaml grows more complex.

  return config;
}

/** Get path to a specific change directory. */
export function changePath(paths: SpecPaths, name: string): string {
  return join(paths.changes, name);
}

/** Get path to an archived change directory. */
export function archivePath(paths: SpecPaths, name: string): string {
  return join(paths.archive, name);
}
