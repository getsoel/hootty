import { existsSync, readFileSync, writeFileSync, unlinkSync, readdirSync, mkdirSync } from "fs";
import { join } from "path";
import { parseYaml, serializeYaml } from "./yaml";

export interface Claim {
  change: string;
  taskGroup: string;
  claimedAt: string;
}

/** Get pane ID from --pane flag or $HOOTTY_PANE_ID environment variable. */
export function resolvePaneId(flagValue?: string): string {
  const id = flagValue || process.env.HOOTTY_PANE_ID;
  if (!id) {
    console.error(
      "error: No pane ID. Pass --pane <id> or run inside a Hootty terminal."
    );
    process.exit(1);
  }
  return id;
}

/** Read a claim for a specific pane. */
export function readClaim(claimsDir: string, paneId: string): Claim | null {
  const path = join(claimsDir, `${paneId}.yaml`);
  if (!existsSync(path)) return null;

  const raw = parseYaml(readFileSync(path, "utf-8"));
  if (!raw.change || !raw.taskGroup) return null;

  return {
    change: raw.change,
    taskGroup: raw.taskGroup,
    claimedAt: raw.claimedAt || "",
  };
}

/** Write a claim for a specific pane. */
export function writeClaim(
  claimsDir: string,
  paneId: string,
  claim: Claim
): void {
  mkdirSync(claimsDir, { recursive: true });
  const path = join(claimsDir, `${paneId}.yaml`);
  writeFileSync(
    path,
    serializeYaml({
      change: claim.change,
      taskGroup: claim.taskGroup,
      claimedAt: claim.claimedAt,
    })
  );
}

/** Remove a claim for a specific pane. */
export function removeClaim(claimsDir: string, paneId: string): boolean {
  const path = join(claimsDir, `${paneId}.yaml`);
  if (!existsSync(path)) return false;
  unlinkSync(path);
  return true;
}

/** List all active claims. */
export function listClaims(
  claimsDir: string
): Array<{ paneId: string; claim: Claim }> {
  if (!existsSync(claimsDir)) return [];

  return readdirSync(claimsDir)
    .filter((f) => f.endsWith(".yaml"))
    .map((f) => {
      const paneId = f.replace(/\.yaml$/, "");
      const claim = readClaim(claimsDir, paneId);
      return claim ? { paneId, claim } : null;
    })
    .filter((x): x is { paneId: string; claim: Claim } => x !== null);
}
