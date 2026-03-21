---
globs: Sources/Hootty/Views/ContentView.swift, Sources/Hootty/Views/SpecView.swift, Sources/Hootty/Views/SpecBarView.swift, Sources/Hootty/Views/PaneGroupView.swift
---

The titlebar has a top-level [Workspaces | Spec] mode picker (AppModel.appMode), shown when the Spec module is enabled. Workspaces mode shows the sidebar + detail layout. Spec mode shows SpecView with change cards grouped by repo.

SpecBarView is a compact per-pane bar showing artifact progress dots for the pane's repo. It sits between PaneBar and TerminalPaneView, and is only shown when Spec is enabled and the pane has a repo with active changes.
