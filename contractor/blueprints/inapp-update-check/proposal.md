## Why

Hootty is distributed via Homebrew Cask, but brew does not push updates — users only receive a new version if they run `brew upgrade --cask hootty`. Today the app has no way to signal that a newer release exists, so users can sit on stale builds indefinitely. A lightweight in-app check closes that gap without requiring Sparkle, codesigning changes, or an appcast.

## What Changes

- Add an update-check service that queries GitHub's `/releases/latest` endpoint on launch (throttled to once per 4h via `UserDefaults`) and compares the returned tag against `Bundle.main.shortVersionString` using numeric component comparison.
- Add a titlebar pill immediately after the existing activity-monitor chip (`ContentView.titleBar`) that appears only when a newer version is detected. Clicking it copies `brew upgrade --cask hootty` to the clipboard and surfaces a brief confirmation.
- Add a settings toggle ("Check for updates on launch", default on) and persist the user's preference in `UserDefaults`.
- Skip the check when the running bundle is not installed under `/Applications/` or the Homebrew Caskroom path (dev builds via `swift run` stay quiet).
- Swallow all network and decode errors silently — this is a nicety, never a blocker.

## Capabilities

### New Capabilities
- `update-check-service`: background polling of the GitHub releases API, version comparison, throttling, and dev-build suppression.
- `update-check-indicator`: the titlebar pill UI, its placement after the activity-monitor chip, click behaviour, and clipboard copy confirmation.
- `update-check-preferences`: the user-facing opt-out toggle and its persistence.

### Modified Capabilities
<!-- none -->

## Impact

- **New files**: `Sources/Hootty/UpdateChecker.swift` (service + model), plus a small view inside `Sources/Hootty/Views/ContentView.swift` or an extracted sibling view for the pill.
- **Modified files**: `Sources/Hootty/Views/ContentView.swift` (insert pill after the activity monitor button), `Sources/Hootty/HoottyApp.swift` (kick off the first check at launch), a settings surface file (TBD in design).
- **No new dependencies**: uses `URLSession`, `JSONDecoder`, `NSPasteboard`, `Bundle.main`, `UserDefaults` only.
- **No signing / CI / release workflow changes**: works identically with today's ad-hoc signed builds.
- **Network**: one HTTPS GET to `api.github.com` per launch (at most every 4h). Unauthenticated — well inside the 60 req/hr per-IP limit.
- **Privacy**: a single outbound request per launch. Mitigated by the opt-out toggle; worth a mention in release notes.
