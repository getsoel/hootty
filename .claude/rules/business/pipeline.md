---
globs: Sources/Hootty/Views/ContentView.swift, Sources/Hootty/Views/WorkshopView.swift, Sources/Hootty/Views/WorkshopBarView.swift, Sources/Hootty/Views/PaneGroupView.swift
---

The titlebar has a top-level [Workspaces | Workshop] mode picker (AppModel.appMode), shown when the Workshop module is enabled. Workspaces mode shows the sidebar + detail layout. Workshop mode shows WorkshopView with change cards grouped by repo.

WorkshopBarView is a compact per-pane bar showing artifact progress dots for the pane's repo. It sits between PaneBar and TerminalPaneView, and is only shown when Workshop is enabled and the pane has a repo with active changes.

Workshop artifacts per change: intent.md → requirements/<capability>/req.md → design.md → tasks.md (linear dependency chain). Active work lives in `workshop/active/`, archived work in `workshop/archive/YYYY-MM-DD-<name>/`, canonical specs in `workshop/specs/`.
