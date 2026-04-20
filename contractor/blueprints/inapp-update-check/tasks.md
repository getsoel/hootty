## 1. Service Scaffolding

- [x] 1.1 Create `Sources/Hootty/UpdateChecker.swift` with a `@MainActor @Observable` `UpdateChecker` class exposing `latestVersion: String?`, `isOutdated: Bool`, and a `justCopied` flag (or equivalent publishable state per design D8)
- [x] 1.2 Add a private `GitHubRelease` `Decodable` struct with a single `tag_name: String` field
- [x] 1.3 Define private constants for the repo slug (`getsoel/hootty`), the GitHub API URL, the 4-hour throttle window, and the `UserDefaults` keys under the `com.soel.hootty.updateCheck.*` namespace (per design D3)

## 2. Version Logic

- [x] 2.1 Implement a `parseVersion(_ string: String) -> [Int]` helper that strips a leading `v`, splits on `.`, and maps components to `Int` (nil → 0) per design D4
- [x] 2.2 Implement `isNewer(remote: String, than local: String) -> Bool` using component-wise `[Int]` comparison; include equal-length and unequal-length cases
- [x] 2.3 Add unit tests in `Tests/HoottyCoreTests/` only if the version logic moves to `HoottyCore`; otherwise inline Swift Testing cases against the `UpdateChecker` type's static helpers (requirement: `update-check-service` — numeric compare scenarios)

## 3. Install-Location Gate

- [x] 3.1 Implement a `isInstalledBuild()` check that returns `true` when `Bundle.main.bundleURL.path` starts with `/Applications/` or contains `/Caskroom/` (design D5, requirement: `update-check-service` — dev build suppression)
- [x] 3.2 Short-circuit `UpdateChecker.check()` with an early return when `isInstalledBuild()` is false, without touching `UserDefaults` or issuing any network request

## 4. Network + Throttle

- [x] 4.1 Implement `UpdateChecker.check()` as an `async` method using `URLSession.shared.data(for:)` with `Accept: application/vnd.github+json` and a 10 s timeout per design D6
- [x] 4.2 Wrap the call in `try? await` so every error path silently no-ops (requirement: `update-check-service` — silent error handling)
- [x] 4.3 Read `lastCheckedAt` from `UserDefaults`; if `CFAbsoluteTimeGetCurrent() - lastCheckedAt < window`, rehydrate cached state from `lastSeenVersion` and return without a network request (requirement: `update-check-service` — throttle window + caching)
- [x] 4.4 On a successful 2xx decode, persist `lastCheckedAt` and `lastSeenVersion`, then update observable properties on the main actor

## 5. Preference Toggle

- [x] 5.1 Read the `optedIn` preference from `UserDefaults` treating absent as `true` (requirement: `update-check-preferences` — default on first launch)
- [x] 5.2 Short-circuit `check()` when `optedIn == false`, ensuring no network request is made (requirement: `update-check-preferences` — opted out)
- [x] 5.3 Add a user-facing toggle in the smallest existing menu surface per design D9 (profile menu, app menu, or pill context menu); persist the new value and recompute `isOutdated` immediately when disabled

## 6. Titlebar Pill

- [x] 6.1 Add `@State private var updateChecker = UpdateChecker()` to `ContentView` (mirroring the `memoryMonitor` pattern, design D2)
- [x] 6.2 Kick off the first `await updateChecker.check()` from a `.task { … }` on `ContentView` (alongside or beside the existing memory-sampling task)
- [x] 6.3 In `titleBar`, insert the update pill immediately after the activity-monitor `Button`, gated by `if updateChecker.isOutdated, let latest = updateChecker.latestVersion` (requirement: `update-check-indicator` — placement)
- [x] 6.4 Style the pill with `TitlebarChip`, include an SF Symbol (`arrow.down.circle.fill`) and the version text, and set a `.help("Copy `brew upgrade --cask hootty` to clipboard")` tooltip (requirement: `update-check-indicator` — label + accessibility)

## 7. Click Action

- [x] 7.1 Implement the click handler to clear `NSPasteboard.general` and set the literal string `brew upgrade --cask hootty` (requirement: `update-check-indicator` — click copies brew command)
- [x] 7.2 Flip the `justCopied` flag, swap the pill label to "Copied" briefly (~1.2 s), and reset via a `Task` so repeat clicks behave correctly (requirement: `update-check-indicator` — repeated clicks)

## 8. Verification

- [x] 8.1 Run `make build` and confirm the release build succeeds
- [x] 8.2 Run `swift test` and confirm the Swift Testing suite passes (ignore signal 10 per `CLAUDE.local.md`)
- [x] 8.3 Run `make format-check` and `make lint`
- [x] 8.4 Launch `make run` with a temporarily pinned low `CFBundleShortVersionString` (e.g. `0.0.1`) in the embedded Info.plist to confirm the pill appears after the activity-monitor chip and copies the brew command on click
- [x] 8.5 Launch `make run` with the current version and confirm the pill stays hidden and no network request is issued (dev build gate from requirement `update-check-service`)
- [x] 8.6 Toggle the opt-out preference off, relaunch, and confirm no update-related network traffic
- [x] 8.7 Revert any local Info.plist version tweaks used for testing before committing
