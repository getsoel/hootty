import { existsSync } from "fs";
import { join } from "path";
import { requireSpecDir, changePath } from "../lib/spec-dir";
import { resolveChange } from "../lib/changes";
import { resolvePaneId, writeClaim } from "../lib/claims";
import { parseTasks } from "../lib/tasks";
import { printSuccess, printError } from "../lib/output";

interface ClaimOpts {
  taskGroup: string;
  change?: string;
  pane?: string;
}

export async function runClaim(opts: ClaimOpts): Promise<void> {
  const paths = requireSpecDir();
  const paneId = resolvePaneId(opts.pane);
  const changeName = resolveChange(paths.changes, opts.change);
  const changeDir = changePath(paths, changeName);

  if (!existsSync(changeDir)) {
    printError(`Change "${changeName}" not found.`);
    process.exit(1);
  }

  const tasksFile = join(changeDir, "tasks.md");
  const groups = parseTasks(tasksFile);

  if (groups.length === 0) {
    printError(`No task groups found in tasks.md for change "${changeName}".`);
    process.exit(1);
  }

  const match = groups.find(
    (g) =>
      g.name === opts.taskGroup ||
      g.name.toLowerCase() === opts.taskGroup.toLowerCase()
  );

  if (!match) {
    printError(
      `Task group "${opts.taskGroup}" not found. Available groups:\n${groups.map((g) => `  - ${g.name}`).join("\n")}`
    );
    process.exit(1);
  }

  writeClaim(paths.claims, paneId, {
    change: changeName,
    taskGroup: match.name,
    claimedAt: new Date().toISOString(),
  });

  printSuccess(
    `Claimed "${match.name}" (${match.completed}/${match.total} done) on change "${changeName}"`
  );
}
