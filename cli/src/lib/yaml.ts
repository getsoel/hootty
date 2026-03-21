/** Minimal YAML parser/writer for flat key-value files. */

export function parseYaml(content: string): Record<string, string> {
  const result: Record<string, string> = {};
  let multilineKey: string | null = null;
  let multilineValue: string[] = [];

  for (const line of content.split("\n")) {
    // Flush multiline if we hit a non-indented line
    if (multilineKey !== null && !line.startsWith("  ") && line.trim() !== "") {
      result[multilineKey] = multilineValue.join("\n").trimEnd();
      multilineKey = null;
      multilineValue = [];
    }

    if (multilineKey !== null) {
      multilineValue.push(line.replace(/^ {2}/, ""));
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const colonIdx = trimmed.indexOf(":");
    if (colonIdx === -1) continue;

    const key = trimmed.slice(0, colonIdx).trim();
    const rawValue = trimmed.slice(colonIdx + 1).trim();

    if (rawValue === "|") {
      multilineKey = key;
      multilineValue = [];
    } else {
      // Strip surrounding quotes
      result[key] = rawValue.replace(/^["']|["']$/g, "");
    }
  }

  // Flush trailing multiline
  if (multilineKey !== null) {
    result[multilineKey] = multilineValue.join("\n").trimEnd();
  }

  return result;
}

export function serializeYaml(data: Record<string, string>): string {
  const lines: string[] = [];
  for (const [key, value] of Object.entries(data)) {
    if (value.includes("\n")) {
      lines.push(`${key}: |`);
      for (const vline of value.split("\n")) {
        lines.push(`  ${vline}`);
      }
    } else {
      lines.push(`${key}: ${value}`);
    }
  }
  return lines.join("\n") + "\n";
}
