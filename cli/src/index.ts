#!/usr/bin/env bun

import { runInit } from "./commands/init";
import { runNew } from "./commands/new";
import { runStatus } from "./commands/status";
import { runInstructions } from "./commands/instructions";
import { runList } from "./commands/list";
import { runArchive } from "./commands/archive";
import { runClaim } from "./commands/claim";
import { runRelease } from "./commands/release";
import { runCurrent } from "./commands/current";

const VERSION = "0.1.0";

function printHelp(): void {
  console.log(`hootty spec — Spec-driven development for Hootty

Usage: hootty spec <command> [options]

Setup:
  init                              Initialize spec/ directory
  new <name>                        Create a new change

Status:
  status [--change <name>] [--json] Show artifact completion status
  list [--json]                     List changes
  instructions <artifact> [--change <name>] [--json]
                                    Get creation instructions for an artifact

Claims:
  claim <task-group> [--change <name>] [--pane <id>]
                                    Claim a task group for a pane
  release [--pane <id>]             Release current claim
  current [--pane <id>] [--json]    Show current claim

Lifecycle:
  archive <name> [--yes]            Archive a completed change

Other:
  version                           Show version
  help                              Show this help`);
}

function parseArgs(argv: string[]): { command: string; args: string[] } {
  // Handle: `hootty spec <cmd>` or direct `spec <cmd>` or just `<cmd>`
  let rest = argv.slice(2); // skip bun/node and script path

  // If first arg is "spec", skip it (called as `hootty spec <cmd>`)
  if (rest[0] === "spec") {
    rest = rest.slice(1);
  }

  const command = rest[0] || "help";
  return { command, args: rest.slice(1) };
}

function getFlag(args: string[], flag: string): string | undefined {
  const idx = args.indexOf(flag);
  if (idx === -1 || idx + 1 >= args.length) return undefined;
  return args[idx + 1];
}

function hasFlag(args: string[], flag: string): boolean {
  return args.includes(flag);
}

async function main(): Promise<void> {
  const { command, args } = parseArgs(process.argv);

  switch (command) {
    case "init":
      await runInit();
      break;
    case "new":
      if (!args[0]) {
        console.error("Usage: hootty spec new <name>");
        process.exit(1);
      }
      await runNew(args[0]);
      break;
    case "status":
      await runStatus({
        change: getFlag(args, "--change"),
        json: hasFlag(args, "--json"),
      });
      break;
    case "instructions":
      if (!args[0]) {
        console.error(
          "Usage: hootty spec instructions <artifact-id> [--change <name>]"
        );
        process.exit(1);
      }
      await runInstructions({
        artifactId: args[0],
        change: getFlag(args, "--change"),
        json: hasFlag(args, "--json"),
      });
      break;
    case "list":
      await runList({ json: hasFlag(args, "--json") });
      break;
    case "archive":
      if (!args[0]) {
        console.error("Usage: hootty spec archive <name> [--yes]");
        process.exit(1);
      }
      await runArchive({
        name: args[0],
        yes: hasFlag(args, "--yes"),
      });
      break;
    case "claim":
      if (!args[0]) {
        console.error(
          "Usage: hootty spec claim <task-group> [--change <name>]"
        );
        process.exit(1);
      }
      await runClaim({
        taskGroup: args[0],
        change: getFlag(args, "--change"),
        pane: getFlag(args, "--pane"),
      });
      break;
    case "release":
      await runRelease({ pane: getFlag(args, "--pane") });
      break;
    case "current":
      await runCurrent({
        pane: getFlag(args, "--pane"),
        json: hasFlag(args, "--json"),
      });
      break;
    case "version":
      console.log(`hootty-spec ${VERSION}`);
      break;
    case "help":
    case "--help":
    case "-h":
      printHelp();
      break;
    default:
      console.error(`Unknown command: ${command}`);
      printHelp();
      process.exit(1);
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});

export { getFlag, hasFlag };
