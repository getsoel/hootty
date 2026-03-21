import { existsSync, readFileSync } from "fs";

export interface TaskItem {
  text: string;
  done: boolean;
}

export interface TaskGroup {
  name: string;
  items: TaskItem[];
  total: number;
  completed: number;
}

/** Parse tasks.md into structured task groups. */
export function parseTasks(filePath: string): TaskGroup[] {
  if (!existsSync(filePath)) return [];

  const content = readFileSync(filePath, "utf-8");
  return parseTasksContent(content);
}

/** Parse tasks.md content string into task groups. */
export function parseTasksContent(content: string): TaskGroup[] {
  const groups: TaskGroup[] = [];
  let current: TaskGroup | null = null;

  for (const line of content.split("\n")) {
    // Detect group headers: ## N. Name or ## Name
    const headerMatch = line.match(/^##\s+(.+)/);
    if (headerMatch) {
      if (current) groups.push(current);
      current = {
        name: headerMatch[1].trim(),
        items: [],
        total: 0,
        completed: 0,
      };
      continue;
    }

    if (!current) continue;

    // Detect checkbox items: - [ ] or - [x]
    const checkboxMatch = line.match(/^[-*]\s+\[([ xX])\]\s+(.*)/);
    if (checkboxMatch) {
      const done = checkboxMatch[1].toLowerCase() === "x";
      current.items.push({ text: checkboxMatch[2].trim(), done });
      current.total++;
      if (done) current.completed++;
    }
  }

  if (current) groups.push(current);
  return groups;
}

/** Get overall progress across all groups. */
export function totalProgress(groups: TaskGroup[]): {
  total: number;
  completed: number;
} {
  let total = 0;
  let completed = 0;
  for (const g of groups) {
    total += g.total;
    completed += g.completed;
  }
  return { total, completed };
}
