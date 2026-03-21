import { requireWorkshopDir } from "../lib/workshop-dir";
import { resolvePaneId, removeClaim, readClaim } from "../lib/claims";
import { printSuccess, printError } from "../lib/output";

interface ReleaseOpts {
  pane?: string;
}

export async function runRelease(opts: ReleaseOpts): Promise<void> {
  const paths = requireWorkshopDir();
  const paneId = resolvePaneId(opts.pane);

  const existing = readClaim(paths.claims, paneId);
  if (!existing) {
    printError("No active claim for this pane.");
    process.exit(1);
  }

  removeClaim(paths.claims, paneId);
  printSuccess(
    `Released claim on "${existing.taskGroup}" (change: ${existing.change})`
  );
}
