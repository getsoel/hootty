import {
  existsSync,
  readdirSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  renameSync,
} from "fs";
import { join } from "path";
import { requireSpecDir, changePath } from "../lib/spec-dir";
import { allArtifactsDone } from "../lib/artifacts";
import { parseTasks, totalProgress } from "../lib/tasks";
import { printSuccess, printError } from "../lib/output";

interface ArchiveOpts {
  name: string;
  yes: boolean;
}

/** Merge delta specs from a change into the accumulated specs directory. */
function mergeSpecs(changeSpecsDir: string, mainSpecsDir: string): number {
  if (!existsSync(changeSpecsDir)) return 0;

  let merged = 0;
  const dirs = readdirSync(changeSpecsDir, { withFileTypes: true });

  for (const d of dirs) {
    if (!d.isDirectory()) continue;
    const srcSpec = join(changeSpecsDir, d.name, "spec.md");
    if (!existsSync(srcSpec)) continue;

    const destDir = join(mainSpecsDir, d.name);
    const destSpec = join(destDir, "spec.md");

    mkdirSync(destDir, { recursive: true });

    if (existsSync(destSpec)) {
      // Append delta content to existing spec
      const existing = readFileSync(destSpec, "utf-8");
      const delta = readFileSync(srcSpec, "utf-8");
      writeFileSync(destSpec, existing.trimEnd() + "\n\n" + delta);
    } else {
      // New capability — copy spec as-is
      writeFileSync(destSpec, readFileSync(srcSpec, "utf-8"));
    }
    merged++;
  }

  return merged;
}

export async function runArchive(opts: ArchiveOpts): Promise<void> {
  const paths = requireSpecDir();
  const changeDir = changePath(paths, opts.name);

  if (!existsSync(changeDir)) {
    printError(`Change "${opts.name}" not found.`);
    process.exit(1);
  }

  // Check artifact completion
  if (!allArtifactsDone(changeDir)) {
    console.warn("Warning: Not all artifacts are complete.");
  }

  // Check task completion
  const groups = parseTasks(join(changeDir, "tasks.md"));
  const { total, completed } = totalProgress(groups);
  if (total > 0 && completed < total) {
    console.warn(`Warning: ${completed}/${total} tasks complete.`);
  }

  if (!opts.yes) {
    // In non-interactive compiled binary, just warn
    console.log(
      `Archiving "${opts.name}". Pass --yes to skip this confirmation.`
    );
    console.log("Proceeding...");
  }

  // Merge delta specs into accumulated specs
  const changeSpecsDir = join(changeDir, "specs");
  const merged = mergeSpecs(changeSpecsDir, paths.specs);
  if (merged > 0) {
    printSuccess(`Merged ${merged} spec(s) into spec/specs/`);
  }

  // Move change to archive
  const archiveDir = join(paths.archive, opts.name);
  if (existsSync(archiveDir)) {
    printError(`Archive already contains "${opts.name}".`);
    process.exit(1);
  }

  mkdirSync(paths.archive, { recursive: true });
  renameSync(changeDir, archiveDir);

  printSuccess(`Archived "${opts.name}" to spec/archive/${opts.name}/`);
}
