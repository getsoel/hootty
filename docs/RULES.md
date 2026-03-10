# Progressive Disclosure for Claude Code

Claude Code loads project instructions from two sources: `CLAUDE.md` (always loaded) and `.claude/rules/` files (loaded based on glob patterns). This document explains how Hootty structures them to minimize irrelevant context.

## How it works

```
CLAUDE.md                          ← Always loaded. Lean: architecture overview,
                                     build commands, "read when..." pointers.

.claude/rules/coding/*.md          ← Loaded when globs match files being worked on.
                                     Contains domain-specific rules and gotchas.

docs/*.md                          ← Never auto-loaded. Read on demand when
                                     CLAUDE.md says "read when [condition]".
```

### Layer 1: CLAUDE.md (always loaded)

Keep this file **lean**. It should contain:
- Build/test commands
- Architecture tree (file → one-line description)
- Data flow summary (one bullet per subsystem)
- "Deep-dive docs" section with `read when...` directives
- Pre-completion checklist

**Do not** put detailed rules, gotchas, or how-to guides here. Those belong in rules files or docs.

### Layer 2: `.claude/rules/` with globs (conditionally loaded)

Each file has YAML frontmatter specifying which source files trigger loading:

```yaml
---
globs: Sources/Hootty/Views/**/*.swift, Sources/Hootty/HoottyApp.swift
---
```

When Claude Code touches or reads files matching these globs, the rule file loads into context. When working on unrelated files, it stays out.

### Layer 3: `docs/` (read on demand)

Full reference docs that are too large for rules files. CLAUDE.md points to them with conditions:

```
- `docs/COMMANDS.md` — read when adding commands or modifying keyboard shortcuts
```

Claude Code reads the file when the task matches the condition.

## Current rule files

| File | Globs | What it covers |
|------|-------|----------------|
| `swift-patterns.md` | `**/*.swift` | @Observable, Codable, SPM, build gotchas — broadly applicable |
| `swiftui.md` | `Views/**/*.swift`, `HoottyApp.swift` | View-specific: layout, cursors, gestures, icons, hidden title bar |
| `ghostty.md` | `Terminal/**/*.swift`, `CGhostty/**` | libghostty API: surfaces, callbacks, clipboard, key handling |
| `design-system.md` | `Views/**/*.swift`, `DesignTokens.swift` | Design tokens, spacing, type scale, component patterns |
| `testing.md` | `HoottyCore/**/*.swift`, `Tests/**/*.swift` | Test strategy, integration vs unit, test isolation |
| `commands.md` | `AppCommand.swift`, `CommandRegistry.swift`, `HoottyApp.swift`, `CommandPaletteView.swift` | Command system: adding commands, dispatch flow |

## Adding a new rule file

1. Create `.claude/rules/coding/<name>.md`
2. Add frontmatter with globs matching the relevant source files:
   ```yaml
   ---
   globs: Sources/Hootty/NewFeature/**/*.swift
   ---
   ```
3. Write concise rules (gotchas, patterns, constraints) — not full docs
4. If there's a corresponding deep-dive doc, add a "read when..." line to CLAUDE.md

### Choosing the right layer

| Content type | Where | Why |
|-------------|-------|-----|
| One-line file description | CLAUDE.md architecture tree | Always needed for navigation |
| "Don't do X because Y" gotcha | `.claude/rules/` with globs | Only needed when touching that code |
| Step-by-step how-to guide | `docs/*.md` | Too large for rules, read on demand |
| Build/test commands | CLAUDE.md | Always needed |
| API reference or design spec | `docs/*.md` | Read when implementing that feature |

### Glob patterns

- `Sources/Hootty/Views/**/*.swift` — all view files recursively
- `Sources/HoottyCore/**/*.swift` — all core model files
- `Sources/Hootty/HoottyApp.swift` — specific file
- `**/*.swift` — all Swift files (use sparingly, for truly universal rules)

Comma-separate multiple patterns: `Sources/Foo/*.swift, Sources/Bar/*.swift`

### Rule file guidelines

- **Concise**: Each rule is 1-3 sentences. No preamble, no examples unless the API is tricky.
- **Prescriptive**: "Do X" / "Never do Y" / "Use X instead of Y". Not "you might want to consider..."
- **Earned**: Only add rules for mistakes that have actually happened. Don't preemptively document every possible pitfall.
- **Scoped**: If a rule only applies to 2 files, glob those 2 files. Don't use `**/*.swift` unless it truly applies everywhere.

## Current docs

| File | Read when... |
|------|-------------|
| `docs/COMMANDS.md` | Adding commands, modifying keyboard shortcuts, working on command palette |
| `docs/DESIGN.md` | Creating/modifying UI components, working with design tokens or theme colors |
| `docs/DEBUGGING.md` | Investigating crashes or runtime issues |
| `docs/HOOKS.md` | Modifying wrapper script, env var injection, attention indicators |
| `docs/REBUILDING.md` | Updating or rebuilding libghostty |
| `docs/CONFIG.md` | Working on config file system or adding new settings |
| `docs/RULES.md` | Adding new rules files or modifying progressive disclosure structure |
