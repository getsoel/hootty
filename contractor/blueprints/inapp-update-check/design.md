## Context

Hootty is a SwiftUI macOS app shipped via Homebrew Cask. The release workflow (`.github/workflows/release.yml`) auto-bumps the cask on every `v*` tag, but `brew` only applies updates when the user runs `brew upgrade`. Users can sit on stale builds indefinitely.

The target integration points already exist:
- `Sources/Hootty/Views/ContentView.swift` hosts `titleBar`, which uses a private `TitlebarChip<Content>` view for the activity-monitor button (lines ~248–284). A sibling chip is the natural home for the update pill.
- `Sources/Hootty/MemoryMonitor.swift` demonstrates the pattern the app uses for ambient background state feeding the titlebar.
- `Sources/Hootty/HoottyApp.swift` is the launch-time entry point where a check can be kicked off.
- The Info.plist is embedded via the linker's `__info_plist` section; `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` reads correctly in both `make run` and installed builds.

Repo conventions (see `context/swift-patterns.md`): observable state is modelled with `@Observable` `@MainActor` classes held by `@State`, not `ObservableObject`. One existing file uses `UserDefaults` (`ConfigFile.swift`); there is no `@AppStorage` precedent yet but it is acceptable for simple toggles.

## Goals / Non-Goals

**Goals:**
- Surface a visible, clickable signal in the titlebar when the running build is older than the latest GitHub release.
- One-click copy of `brew upgrade --cask hootty` to the pasteboard.
- No new dependencies, no CI changes, no codesigning work.
- Fail closed: any error, dev build, or opt-out leaves the UI unchanged.
- Stay inside the app's existing patterns (`@Observable`/`@MainActor`, `TitlebarChip`, `@State` in `ContentView`).

**Non-Goals:**
- Auto-installing the update (that is the Sparkle path, explicitly deferred).
- Detecting install source (brew vs. direct DMG) — we always assume brew.
- Prerelease / beta channel support.
- Release-notes display, changelog rendering, or diff summaries.
- Background polling while the app runs idle (the check is launch-time + re-check when throttle window elapses on view appearance).
- Menu-bar "Check for Updates…" item (can be added later under a separate change).

## Decisions

### D1. Single file, UI-layer service
Create `Sources/Hootty/UpdateChecker.swift` containing a `@Observable @MainActor` class `UpdateChecker` plus a small `GitHubRelease` decode struct. Kept in `Hootty` (not `HoottyCore`) because the indicator depends on `NSPasteboard` and `Bundle.main` lookups, and because `HoottyCore` is deliberately UI-free.

Alternatives considered:
- Put the model in `HoottyCore` and inject `Bundle` values. Rejected — no existing consumers in the pure-model layer, and it adds seams for no benefit.
- Split into `UpdateService` + `UpdateChecker` view model. Rejected — ~150 lines total, an extra seam would be overkill.

### D2. `@Observable` held by `@State` in `ContentView`
Follow the `MemoryMonitor` precedent: `@State private var updateChecker = UpdateChecker()` on `ContentView`. Kick off the first poll from the same `.task { … }` block that drives the memory sampler, or a sibling `.task`.

Alternatives considered:
- Put the state on `HoottyApp` (app level). Would work, but `ContentView` already owns comparable ambient state (`memoryMonitor`) and the indicator only lives in that view's titlebar.

### D3. Throttling via `UserDefaults` keys
Three keys under a namespace (`com.soel.hootty.updateCheck.*`):
- `lastCheckedAt` (`Double`, CFAbsoluteTime) — timestamp of the last successful check.
- `lastSeenVersion` (`String`) — the remote version returned by the last successful check. Used to re-emit the cached result at launch without issuing a network call.
- `optedIn` (`Bool`, default `true`) — user preference. Read via explicit `object(forKey:)` so an absent value is treated as `true`, not `false`.

Throttle window: 4 hours, expressed as `14_400` seconds in a private constant. The check returns early without network I/O when `now - lastCheckedAt < window`.

Alternatives considered:
- `@AppStorage`. Works but breaks the pattern set by `ConfigFile.swift`, and we need an "absent = true" default for `optedIn` which is easier with direct `UserDefaults` reads.
- Separate plist or file on disk. Overkill for three scalars.

### D4. Version compare via component-wise integers
Strip a leading `v`, split on `.`, map to `Int` (nil → treat as 0). Compare lexicographically as `[Int]`. Avoids the `"0.10.0" < "0.2.0"` string-compare bug and is robust to `0.3` vs `0.3.0` length differences.

Alternatives considered:
- `String.compare(_:options:.numeric)`. Works for the cases we care about today but carries unclear semantics for any future pre-release suffixes. Explicit parsing is clearer.
- A full SemVer library. New dependency for a ~10-line parser. Not worth it.

### D5. Dev-build suppression via bundle-path check
`Bundle.main.bundleURL.path` is inspected at launch. The check proceeds only when the path starts with `/Applications/` or contains `/Caskroom/` (Homebrew's install root is `/opt/homebrew/Caskroom/hootty/<version>/Hootty.app` on Apple Silicon, `/usr/local/Caskroom/...` on Intel — substring matches both). Anything else (DerivedData, `.build/release/Hootty.app` launched via `make run`) is treated as a dev build and skipped silently.

Alternatives considered:
- A compile-time `#if DEBUG` gate. Would suppress production `make run` debug builds but wouldn't catch someone running a `Release` config locally out of `.build/`. Bundle-path check is a closer match to "am I actually installed?".
- Env var escape hatch for QA. Deferred; can be added if needed.

### D6. Network: `URLSession.shared` with 10s timeout
Use `URLSession.shared.data(for:)` with `async`/`await`, a custom `URLRequest` setting `Accept: application/vnd.github+json` and a 10-second timeout. No retries. Non-2xx responses are treated as errors and swallowed.

Alternatives considered:
- A dedicated `URLSession` with disk cache. GitHub's `Cache-Control` already handles this well enough; we don't need our own cache layer.

### D7. Pill UI as a fourth element in `titleBar`'s HStack
Insert a new view (a private `var updatePill: some View` on `ContentView`, or a small sibling file) immediately after the activity-monitor `Button`, guarded by `if updateChecker.isOutdated, let latest = updateChecker.latestVersion`. Reuse the existing `TitlebarChip` so styling stays consistent. Use an SF Symbol (`arrow.down.circle.fill`) plus the version string for clear affordance.

Alternatives considered:
- Standalone floating badge. Inconsistent with the existing chip language.
- Replacing/merging with the memory chip. Mixes unrelated signals.

### D8. Click action: `NSPasteboard` + transient confirmation
Click handler:
```
let pb = NSPasteboard.general
pb.clearContents()
pb.setString("brew upgrade --cask hootty", forType: .string)
```
Confirmation: the pill label briefly swaps to "Copied" for ~1.2 s via a private `@State var justCopied: Bool` plus a `Task` that resets it. No toast framework required. The chip's `help(_:)` tooltip always reads "Copy `brew upgrade --cask hootty` to clipboard".

Alternatives considered:
- A sheet/popover with release notes. More work than the 80% scope allows; can be added later.
- `NSUserNotification` / system toast. Unnecessary and intrusive.

### D9. Preference surface — deferred to the smallest existing menu hook
The toggle lives in the profile menu (adjacent to existing "New Profile / Rename / Delete" entries) or in the menu bar's app menu — whichever the implementer finds already wired. If no clean surface exists, the toggle lives inline in the pill's context menu ("Don't notify me about updates"). The requirement only says the toggle must be discoverable; the exact surface is a small decision the implementer can make during tasks, but it MUST NOT require building a new preferences window.

Alternatives considered:
- A full Settings/Preferences scene. Explicit non-goal for this change; Hootty has no existing Settings scene to build on.

### D10. Concurrency
`UpdateChecker` is `@MainActor`. The network call uses `URLSession`'s `async` API which suspends off the main actor, then results are applied back on main (natural with `await`). No `nonisolated` annotations required. Follows the `@MainActor @Observable` rule in `context/swift-patterns.md`.

## Risks / Trade-offs

- **[Risk] GitHub API rate limit** — unauthenticated 60 req/hr per IP. → 4-hour throttle + single request per launch keeps any realistic user well under, and the failure mode on 403 is the same silent no-op as any other network error.
- **[Risk] Users on a dev-published fork still hit `getsoel/hootty`** — the repo slug is hardcoded. → Acceptable for this scope; if forks become a concern, read the slug from Info.plist later.
- **[Risk] Prerelease tags create confusing comparisons** — `/releases/latest` excludes prereleases server-side, so the current risk is zero unless GitHub's behaviour changes or someone promotes a prerelease manually. → Documented in requirements; revisit if we ever ship a beta channel.
- **[Risk] `CFAbsoluteTime` clock skew across reboots** — system time jumps could make the throttle misbehave. → In practice only bounds how often we call; a stuck-in-past clock at worst means we check more often. Acceptable.
- **[Risk] Brittle `TitlebarChip` reuse** — `TitlebarChip` is declared `private` inside `ContentView.swift`. → Because the pill lives in `ContentView.swift`, the private scope is fine. If the pill moves to its own file, promote `TitlebarChip` to `fileprivate` (same file) or `internal`.
- **[Risk] Opt-out toggle placement is fuzzy** — D9 leaves the exact menu to the implementer. → Captured as an open question; tasks will pin it down.

## Migration Plan

None. This is purely additive:
- No schema changes, no persisted user data migration (fresh keys default to the correct values).
- Rollback is a single revert — no servers, no stored state to clean up.

## Open Questions

1. **Where exactly does the opt-out toggle live?** Candidates: profile menu, app menu bar, a context menu on the pill. Implementer's call during tasks; preference is whichever touches the least code.
2. **Should the pill disappear for 24h after a copy, or stay visible until the app version actually matches?** Current plan: stays visible until the detected version changes. Safer nag vs. annoyance trade-off; revisit if users complain.
3. **Should we expose "Check now" anywhere?** Not required for the 80% option; deferred until we hear from a user who wants it.
