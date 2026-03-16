---
globs: Sources/Hootty/Views/ContentView.swift, Sources/Hootty/Views/WorkspaceSidebar.swift, Sources/Hootty/Views/PipelineBoardView.swift, Sources/Hootty/Views/PipelineBarView.swift, Sources/Hootty/Views/PipelinesView.swift
---

The titlebar has a top-level [Workspaces | Pipelines] mode picker (AppModel.appMode). Workspaces mode shows the sidebar + detail layout. Pipelines mode shows PipelinesView with its own [Boards | Templates] sub-tabs (AppModel.pipelineMode).

The sidebar tab picker (Terminals / Board) controls the main detail area, not the sidebar content. The sidebar workspace tree always remains visible regardless of which tab is active. Board view replaces the terminal split panes in the detail area.
