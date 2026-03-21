import { existsSync } from "fs";
import { join } from "path";
import { requireSpecDir, changePath } from "../lib/spec-dir";
import { resolvePaneId, readClaim } from "../lib/claims";
import { parseTasks } from "../lib/tasks";
import { printJson } from "../lib/output";

interface CurrentOpts {
  pane?: string;
  json: boolean;
}

export async function runCurrent(opts: CurrentOpts): Promise<void> {
  const paths = requireSpecDir();
  const paneId = resolvePaneId(opts.pane);

  const claim = readClaim(paths.claims, paneId);
  if (!claim) {
    if (opts.json) {
      printJson({ claimed: false });
    } else {
      console.log("No active claim for this pane.");
    }
    return;
  }

  // Read task progress for the claimed group
  const changeDir = changePath(paths, claim.change);
  const tasksFile = join(changeDir, "tasks.md");
  const groups = parseTasks(tasksFile);
  const group = groups.find((g) => g.name === claim.taskGroup);

  if (opts.json) {
    printJson({
      claimed: true,
      paneId,
      change: claim.change,
      taskGroup: claim.taskGroup,
      claimedAt: claim.claimedAt,
      progress: group
        ? { total: group.total, completed: group.completed, items: group.items }
        : null,
    });
  } else {
    console.log(`Change: ${claim.change}`);
    console.log(`Task group: ${claim.taskGroup}`);
    if (group) {
      console.log(`Progress: ${group.completed}/${group.total}`);
      for (const item of group.items) {
        console.log(`  ${item.done ? "[x]" : "[ ]"} ${item.text}`);
      }
    }
  }
}
