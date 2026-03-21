import { existsSync } from "fs";
import { join } from "path";
import { requireWorkshopDir, changePath } from "../lib/workshop-dir";
import { listChangeNames } from "../lib/changes";
import { resolveArtifacts, type ArtifactInfo } from "../lib/artifacts";
import { parseTasks, totalProgress } from "../lib/tasks";
import { printJson, printError } from "../lib/output";

interface StatusOpts {
  change?: string;
  json: boolean;
}

function stateIcon(state: string): string {
  switch (state) {
    case "done":
      return "\u2713";
    case "ready":
      return "\u25CB";
    case "blocked":
      return "\u00B7";
    default:
      return "?";
  }
}

function printChangeStatus(
  name: string,
  artifacts: ArtifactInfo[],
  changDir: string
): void {
  console.log(`\n  ${name}`);
  for (const a of artifacts) {
    const icon = stateIcon(a.state);
    const stateLabel = a.state.padEnd(7);
    console.log(`    ${icon} ${a.id.padEnd(10)} ${stateLabel}  ${a.description}`);
  }

  // Show task progress if tasks.md exists
  const tasksFile = join(changDir, "tasks.md");
  const groups = parseTasks(tasksFile);
  if (groups.length > 0) {
    const { total, completed } = totalProgress(groups);
    console.log(`    Tasks: ${completed}/${total} complete`);
  }
}

export async function runStatus(opts: StatusOpts): Promise<void> {
  const paths = requireWorkshopDir();

  if (opts.change) {
    const dir = changePath(paths, opts.change);
    if (!existsSync(dir)) {
      printError(`Change "${opts.change}" not found.`);
      process.exit(1);
    }
    const artifacts = resolveArtifacts(dir);

    if (opts.json) {
      const groups = parseTasks(join(dir, "tasks.md"));
      printJson({ change: opts.change, artifacts, taskGroups: groups });
    } else {
      printChangeStatus(opts.change, artifacts, dir);
    }
    return;
  }

  // Show all active changes
  const changes = listChangeNames(paths.changes);

  if (changes.length === 0) {
    console.log("No active changes.");
    return;
  }

  if (opts.json) {
    const result = changes.map((name) => {
      const dir = changePath(paths, name);
      const artifacts = resolveArtifacts(dir);
      const groups = parseTasks(join(dir, "tasks.md"));
      return { change: name, artifacts, taskGroups: groups };
    });
    printJson(result);
    return;
  }

  console.log("Active changes:");
  for (const name of changes) {
    const dir = changePath(paths, name);
    const artifacts = resolveArtifacts(dir);
    printChangeStatus(name, artifacts, dir);
  }
}
