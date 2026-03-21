---
globs: Sources/HoottyCore/ModuleFlags.swift, Sources/HoottyCore/AppModel.swift, Sources/Hootty/Views/ContentView.swift, Sources/Hootty/Views/SplitView.swift, Sources/Hootty/Views/PaneGroupView.swift, Sources/Hootty/Views/WorkspaceSidebar.swift, Sources/Hootty/HoottyApp.swift
---

Thread `moduleFlags: ModuleFlags` through the view hierarchy — never individual boolean parameters like `workshopEnabled: Bool`. Adding a new module should require adding one field to `ModuleFlags`, not a new parameter on every view in the chain.

Views check `moduleFlags.workshop`. `HoottyApp.swift` and `ContentView.swift` access `appModel.workshopEnabled` directly (they have model access — no threading needed).

Config keys follow the pattern `hootty-module-<name>`. The `hootty-` prefix ensures they're filtered out of ghostty config. Use `configFile.defaultFalseBool()` / `configFile.setDefaultFalseBool()` for the accessor pattern. Default is disabled (experimental — key absent or not `"true"`). Toggle commands (`toggleWorkshop`) are registered unconditionally in the command palette.

Guard module UI at the outermost boundary (view, callback, watcher). Don't sprinkle checks inside model code — model types should work unconditionally.

When adding a new module, follow the checklist in `docs/MODULES.md`.
