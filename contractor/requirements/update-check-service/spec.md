## ADDED Requirements

### Requirement: Launch-time update poll
The app SHALL query GitHub's `/repos/getsoel/hootty/releases/latest` endpoint at launch to discover the latest released version, provided the throttle window has elapsed and the user has not opted out.

#### Scenario: First launch with network available
- **WHEN** the app launches, the preferences toggle is on, and no prior check timestamp exists
- **THEN** the service issues a single unauthenticated HTTPS GET to `https://api.github.com/repos/getsoel/hootty/releases/latest`
- **AND** records the timestamp of the check in `UserDefaults`

#### Scenario: Launch within throttle window
- **WHEN** the app launches and the last successful check was less than 4 hours ago
- **THEN** the service MUST NOT issue a network request
- **AND** MUST re-emit the previously cached result

#### Scenario: Launch outside throttle window
- **WHEN** the app launches and the last successful check was at least 4 hours ago
- **THEN** the service issues a fresh network request and updates the cached result

### Requirement: Numeric version comparison
The service SHALL compare the remote tag against the locally running version using component-wise numeric comparison so that multi-digit components order correctly.

#### Scenario: Remote version is strictly greater
- **WHEN** the remote `tag_name` is `v0.10.0` and the local `CFBundleShortVersionString` is `0.2.0`
- **THEN** the service classifies the local build as outdated

#### Scenario: Remote version equals local
- **WHEN** the remote `tag_name` is `v0.3.1` and the local version is `0.3.1`
- **THEN** the service classifies the local build as up-to-date

#### Scenario: Local version is ahead of latest release
- **WHEN** the local version is numerically greater than the remote `tag_name`
- **THEN** the service classifies the local build as up-to-date and never surfaces the indicator

#### Scenario: Leading v prefix on the tag
- **WHEN** the remote `tag_name` is prefixed with `v` (e.g. `v0.3.1`)
- **THEN** the service strips the prefix before parsing components

### Requirement: Development build suppression
The service SHALL skip the update check entirely when the running executable is not installed in a recognised install location, so `swift run` development builds do not display stale update prompts.

#### Scenario: Bundle installed under /Applications
- **WHEN** `Bundle.main.bundleURL.path` begins with `/Applications/`
- **THEN** the service proceeds with the check

#### Scenario: Bundle installed under Homebrew Caskroom
- **WHEN** `Bundle.main.bundleURL.path` contains `/Caskroom/`
- **THEN** the service proceeds with the check

#### Scenario: Bundle running from a development path
- **WHEN** the bundle path is neither under `/Applications/` nor contains `/Caskroom/`
- **THEN** the service MUST NOT issue a network request
- **AND** the indicator MUST NOT be shown

### Requirement: Silent error handling
The service SHALL treat every failure mode (network error, non-200 status, decode failure, missing tag) as a no-op and MUST NOT surface any user-visible error.

#### Scenario: Network request fails
- **WHEN** the `URLSession` task completes with an error or a non-200 status
- **THEN** the service logs the failure at debug level only
- **AND** leaves the cached "up-to-date" state unchanged
- **AND** does not update the last-check timestamp

#### Scenario: Response payload cannot be decoded
- **WHEN** the JSON body is missing `tag_name` or cannot be parsed as expected
- **THEN** the service treats the response as a no-op under the same rules as a network failure

### Requirement: Result caching
The service SHALL cache the most recent successful result in `UserDefaults` so repeat launches within the throttle window restore the previous indicator state without a network call.

#### Scenario: Previously outdated, still within window
- **WHEN** a prior check determined the app was outdated and the throttle window has not elapsed
- **THEN** the indicator state re-emits "outdated" at launch without issuing a network request

#### Scenario: Previously up-to-date, still within window
- **WHEN** a prior check determined the app was up-to-date and the throttle window has not elapsed
- **THEN** the indicator stays hidden at launch without issuing a network request
