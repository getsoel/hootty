import { existsSync, readdirSync, readFileSync } from "fs";
import { join } from "path";
import { requireSpecDir, changePath } from "../lib/spec-dir";
import { resolveArtifacts } from "../lib/artifacts";
import { parseTasks, totalProgress } from "../lib/tasks";
import { parseYaml } from "../lib/yaml";
import { printJson } from "../lib/output";

interface ListOpts {
  json: boolean;
}

interface ChangeEntry {
  name: string;
  created?: string;
  archived: boolean;
  artifactsDone: number;
  artifactsTotal: number;
  tasksDone: number;
  tasksTotal: number;
}

function readChangeMeta(
  dir: string
): { created?: string; schema?: string } | null {
  const metaPath = join(dir, ".spec.yaml");
  if (!existsSync(metaPath)) return null;
  return parseYaml(readFileSync(metaPath, "utf-8"));
}

function scanDir(
  basePath: string,
  archived: boolean
): ChangeEntry[] {
  if (!existsSync(basePath)) return [];
  return readdirSync(basePath, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith("."))
    .map((d) => {
      const dir = join(basePath, d.name);
      const meta = readChangeMeta(dir);
      const artifacts = resolveArtifacts(dir);
      const groups = parseTasks(join(dir, "tasks.md"));
      const { total, completed } = totalProgress(groups);
      return {
        name: d.name,
        created: meta?.created,
        archived,
        artifactsDone: artifacts.filter((a) => a.state === "done").length,
        artifactsTotal: artifacts.length,
        tasksDone: completed,
        tasksTotal: total,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

export async function runList(opts: ListOpts): Promise<void> {
  const paths = requireSpecDir();

  const active = scanDir(paths.changes, false);
  const archived = scanDir(paths.archive, true);
  const all = [...active, ...archived];

  if (opts.json) {
    printJson(all);
    return;
  }

  if (all.length === 0) {
    console.log("No changes. Run `hootty spec new <name>` to create one.");
    return;
  }

  if (active.length > 0) {
    console.log("Active:");
    for (const c of active) {
      const artifacts = `${c.artifactsDone}/${c.artifactsTotal} artifacts`;
      const tasks =
        c.tasksTotal > 0 ? `, ${c.tasksDone}/${c.tasksTotal} tasks` : "";
      console.log(`  ${c.name}  (${artifacts}${tasks})`);
    }
  }

  if (archived.length > 0) {
    if (active.length > 0) console.log("");
    console.log("Archived:");
    for (const c of archived) {
      console.log(`  ${c.name}  (${c.created || ""})`);
    }
  }
}
