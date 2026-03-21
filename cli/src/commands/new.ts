import { existsSync, mkdirSync, writeFileSync } from "fs";
import { requireWorkshopDir, changePath } from "../lib/workshop-dir";
import { serializeYaml } from "../lib/yaml";
import { printSuccess, printError } from "../lib/output";

const KEBAB_CASE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

export async function runNew(name: string): Promise<void> {
  if (!KEBAB_CASE.test(name)) {
    printError(
      `Invalid change name: "${name}". Use kebab-case (e.g., add-user-auth).`
    );
    process.exit(1);
  }

  const paths = requireWorkshopDir();
  const dir = changePath(paths, name);

  if (existsSync(dir)) {
    printError(`Change "${name}" already exists.`);
    process.exit(1);
  }

  // Create change scaffold
  mkdirSync(dir, { recursive: true });
  mkdirSync(`${dir}/specs`, { recursive: true });

  // Write per-change metadata
  writeFileSync(
    `${dir}/.workshop.yaml`,
    serializeYaml({
      schema: "spec-driven",
      created: new Date().toISOString().split("T")[0],
    })
  );

  printSuccess(`Created change: ${name}`);
  printSuccess(`  workshop/changes/${name}/`);
  printSuccess("");
  printSuccess("Next: create artifacts in order:");
  printSuccess("  1. proposal.md  (why and what)");
  printSuccess("  2. specs/       (behavioral specifications)");
  printSuccess("  3. design.md    (technical decisions)");
  printSuccess("  4. tasks.md     (implementation checklist)");
}
