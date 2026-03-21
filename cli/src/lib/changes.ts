import { existsSync, readdirSync } from "fs";
import { printError } from "./output";

/** List active change directory names. */
export function listChangeNames(changesDir: string): string[] {
  if (!existsSync(changesDir)) return [];
  return readdirSync(changesDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith("."))
    .map((d) => d.name)
    .sort();
}

/** Resolve to a single active change name. Errors if none or ambiguous. */
export function resolveChange(
  changesDir: string,
  explicit?: string
): string {
  if (explicit) return explicit;

  const changes = listChangeNames(changesDir);

  if (changes.length === 0) {
    printError("No active changes.");
    process.exit(1);
  }
  if (changes.length > 1) {
    printError(
      `Multiple active changes. Use --change <name>: ${changes.join(", ")}`
    );
    process.exit(1);
  }
  return changes[0];
}
