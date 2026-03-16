# Template Editor — Spec

## Overview

An in-app UI for managing global pipeline templates. Templates are YAML files stored in `~/Library/Application Support/Hootty/pipeline-templates/`. The editor lets users browse, create, edit, duplicate, and delete templates without leaving the app or touching the CLI.

## Goals

1. **Self-contained** — Users should never need `$EDITOR` or the CLI to manage templates.
2. **Visual stage editing** — Add, remove, reorder stages and toggle type (auto/manual) with direct manipulation, not YAML editing.
3. **Consistent** — Follow existing Hootty patterns (design tokens, spacing, component structure).
4. **Non-destructive defaults** — Built-in templates (simple, review, full-ci) can be modified, but a "Reset Defaults" action restores them.

## Entry Point

The existing `TemplatesView` (currently a placeholder) becomes the template editor. It is accessed via the sidebar tab picker when the detail mode is set to templates. The sidebar workspace tree remains visible — only the detail area changes.

Alternatively, the "Create Pipeline" sheet's template picker could include an "Edit Templates..." link that opens the editor.

## UI Structure

### Layout

```
┌─────────────────────────────────────────────────────┐
│  Template List (left)    │  Template Detail (right)  │
│                          │                           │
│  ┌────────────────────┐  │  Name: [Review         ]  │
│  │ ● simple           │  │                           │
│  │ ● review      ←sel │  │  Stages:                  │
│  │ ● full-ci          │  │  ┌──────────────────────┐  │
│  │ ● my-custom        │  │  │ ≡ Backlog    manual  │  │
│  │                     │  │  │ ≡ Implement  auto    │  │
│  │                     │  │  │ ≡ Review     manual  │  │
│  │  [+] New Template   │  │  │ ≡ Done       manual  │  │
│  │                     │  │  └──────────────────────┘  │
│  │                     │  │  [+ Add Stage]             │
│  │                     │  │                           │
│  │                     │  │  Settings:                │
│  │                     │  │  ☑ Pause on error         │
│  │                     │  │  Max claims: [__]         │
│  └────────────────────┘  │                           │
│                          │  [Delete Template]         │
│                          │  [Reset Defaults]          │
└─────────────────────────────────────────────────────┘
```

Two-pane master-detail layout inside the detail area:

- **Left pane (template list)**: Scrollable list of template names with selection highlight. "New Template" button at the bottom.
- **Right pane (template detail)**: Editable form for the selected template. Empty state when nothing is selected.

### Template List

- Each row shows the template name (derived from filename, title-cased).
- Selection uses `elementSelected` background (sharp rectangle, no rounded corners — follows sidebar pattern but this is detail area so rounded is fine here).
- Context menu on each row: Duplicate, Delete.
- "New Template" button at the bottom creates a template with a default name ("untitled") and the review stages, selects it immediately.

### Template Detail

#### Name Field
- Editable text field. Changing the name renames the YAML file on disk (slug-derived: lowercased, spaces to hyphens).
- Validation: non-empty, no duplicate names.

#### Stage List
- Vertical list of stages in pipeline order.
- Each row shows:
  - **Drag handle** (≡ icon) for reordering via drag-and-drop.
  - **Stage name** — inline editable text field.
  - **Type toggle** — segmented control or button toggling between `manual` and `auto`.
  - **Command field** — appears below the row when type is `auto`. Single-line text field for the stage command.
  - **Delete button** — appears on hover, removes the stage.
- Reordering uses standard SwiftUI `onMove` or drag-and-drop.
- "Add Stage" button below the list appends a new manual stage named "New Stage".
- Minimum 2 stages enforced (disable delete when at 2).

#### Settings Section
- **Pause on error** — toggle (maps to `settings.pause_on_error`).
- **Max claims** — optional integer field (nil = unlimited).

#### Actions
- **Delete Template** — destructive button with confirmation alert. Disabled for the last remaining template.
- **Reset Defaults** — restores the 3 built-in templates (simple, review, full-ci). Confirmation alert warns this overwrites any customizations to those names.

### Persistence

All changes save immediately (no explicit Save button). Each mutation:
1. Calls `TemplateStore.saveTemplate(name:config:)` for content changes.
2. For renames: saves under new name, deletes old file.

This matches the file-first design principle — the YAML files are always the source of truth.

## Data Flow

```
TemplateStore (PipelineKit)
    ↕ reads/writes YAML files
TemplateEditorView (Hootty/Views/)
    ↕ @State for selection, editing state
    ↕ calls TemplateStore methods directly (no model layer needed — simple CRUD)
```

The view holds:
- `@State var templates: [(name: String, config: PipelineConfig)]` — loaded on appear, refreshed after mutations.
- `@State var selectedTemplateName: String?` — current selection.
- Editing state is derived from the selected template's config.

No `@Observable` model class needed — the `TemplateStore` is stateless (file I/O only) and the view refreshes its local state after each mutation.

## Component Breakdown

### New Files
- `Sources/Hootty/Views/TemplateEditorView.swift` — replaces the placeholder `TemplatesView`. Contains the two-pane layout, list, and detail form.

### Modified Files
- `Sources/Hootty/Views/ContentView.swift` — swap `TemplatesView(tokens:)` for `TemplateEditorView(tokens:)`.
- `Sources/Hootty/Views/ContentView.swift` — after editing templates, the "Create Pipeline" sheet should reload `availableTemplates` from the store.

### No Model Changes
`TemplateStore` (PipelineKit) already has all the needed API: `listTemplates()`, `loadTemplate(name:)`, `saveTemplate(name:config:)`, `deleteTemplate(name:)`, `seedDefaults()`.

## Design Tokens

Follow `docs/DESIGN.md` component patterns:

| Element | Token |
|---------|-------|
| Background | `tokens.background` |
| List background | `tokens.surface` |
| Detail background | `tokens.surface` |
| Selected row | `tokens.elementSelected` |
| Hover row | `tokens.elementHover` |
| Text | `tokens.text` |
| Labels / secondary | `tokens.textMuted` |
| Accent actions | `tokens.textAccent` |
| Divider between panes | `tokens.border` |
| Destructive actions | `tokens.statusError` |
| Text fields | `tokens.surfaceHighlight` background, `tokens.border` stroke |
| Spacing | `Spacing.*` constants |
| Font sizes | `TypeScale.*` constants |

## Interaction Details

### Creating a Template
1. Click "+ New Template".
2. A new file `untitled.yaml` is created with review stages.
3. It appears in the list, auto-selected.
4. The name field is focused for immediate rename.

### Duplicating a Template
1. Right-click a template, choose "Duplicate".
2. A copy is created as `<name>-copy.yaml`.
3. Auto-selected for editing.

### Deleting a Template
1. Click "Delete Template" in detail pane (or context menu).
2. Confirmation alert: "Delete template '<name>'? This cannot be undone."
3. On confirm: file deleted, selection moves to adjacent template.

### Reordering Stages
1. Drag a stage row by the handle.
2. Drop between other rows to reorder.
3. Config saves immediately on drop.

### Renaming a Template
1. Edit the name field.
2. On commit (Return or focus loss): old file deleted, new file saved.
3. If the new name conflicts with an existing template, append "-2" (or show inline error).

## Edge Cases

- **Empty store**: Show "No templates" empty state with "Reset Defaults" button.
- **Filesystem errors**: Log via `os.Logger`, show inline error text (not alerts for every save).
- **Concurrent CLI edits**: The view reloads from disk on appear. No live file watching (not worth the complexity for template files that change rarely).
- **Template in use by pipelines**: Deleting a template doesn't affect existing pipelines — they already have their own `pipeline.yaml` copied from the template at init time.

## Out of Scope

- Live YAML editor / raw YAML view toggle (keep it visual-only for now).
- Template variables editor (the `settings.variables` dict) — low usage, can edit via CLI.
- Template sharing / import-export.
- Undo/redo for template edits.
