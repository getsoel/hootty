import { join } from "path";
import { requireWorkshopDir, changePath } from "../lib/workshop-dir";
import { resolvePaneId, readClaim } from "../lib/claims";
import { parseTasks } from "../lib/tasks";
import { printJson } from "../lib/output";

interface CurrentOpts {
  pane?: string;
  json: boolean;
}

export async function runCurrent(opts: CurrentOpts): Promise<void> {
  const paths = requireWorkshopDir();
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

  let group = undefined;
  if (claim.taskGroup) {
    const changeDir = changePath(paths, claim.change);
    const groups = parseTasks(join(changeDir, "tasks.md"));
    group = groups.find((g) => g.name === claim.taskGroup);
  }

  if (opts.json) {
    printJson({
      claimed: true,
      paneId,
      change: claim.change,
      taskGroup: claim.taskGroup ?? null,
      claimedAt: claim.claimedAt,
      progress: group
        ? { total: group.total, completed: group.completed, items: group.items }
        : null,
    });
  } else {
    console.log(`Change: ${claim.change}`);
    if (claim.taskGroup) {
      console.log(`Task group: ${claim.taskGroup}`);
    }
    if (group) {
      console.log(`Progress: ${group.completed}/${group.total}`);
      for (const item of group.items) {
        console.log(`  ${item.done ? "[x]" : "[ ]"} ${item.text}`);
      }
    }
  }
}
