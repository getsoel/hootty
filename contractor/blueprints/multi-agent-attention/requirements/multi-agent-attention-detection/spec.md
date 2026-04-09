## ADDED Requirements

### Requirement: Agent presence state model
The system SHALL define an `AgentPresence` enum with exactly three cases: `thinking`, `idle`, and `needsAttention`. These cases MUST represent the complete set of detectable agent activity states across all supported agent CLIs.

#### Scenario: Enum completeness
- **WHEN** any `AgentTitleDetector` returns a non-nil presence
- **THEN** the value MUST be one of `.thinking`, `.idle`, or `.needsAttention`

#### Scenario: Distinct semantics
- **WHEN** a detector needs to signal "agent is processing"
- **THEN** it MUST return `.thinking`
- **WHEN** a detector needs to signal "agent is waiting with no outstanding attention request"
- **THEN** it MUST return `.idle`
- **WHEN** a detector needs to signal "agent has explicitly flagged that user input is required"
- **THEN** it MUST return `.needsAttention`

### Requirement: Agent title detector protocol
The system SHALL define an `AgentTitleDetector` protocol with two static methods: `detect(_ title: String) -> AgentPresence?` and `stripPrefix(_ title: String) -> String?`. Concrete detectors MUST implement both.

#### Scenario: Detection returns nil for non-matching titles
- **WHEN** a detector receives a title that does not match its agent's pattern
- **THEN** `detect` MUST return `nil`

#### Scenario: stripPrefix returns nil for non-matching titles
- **WHEN** a detector receives a title that does not match its agent's pattern
- **THEN** `stripPrefix` MUST return `nil`

#### Scenario: stripPrefix returns cleaned text for matching titles
- **WHEN** a detector receives a title that matches its agent's pattern
- **THEN** `stripPrefix` MUST return the title with the agent's prefix indicator and any adjacent whitespace removed

### Requirement: Agent title detection registry
The system SHALL provide an `AgentTitleDetection` entry point that runs all registered detectors in order and returns the first non-nil result from `detect(_:)` and `stripPrefix(_:)` independently. The registry MUST include detectors for Claude Code, Gemini CLI, and OpenAI Codex CLI.

#### Scenario: First match wins
- **WHEN** multiple detectors would match a given title
- **THEN** `AgentTitleDetection.detect(_:)` MUST return the result from the first detector in registration order

#### Scenario: No detector matches
- **WHEN** no detector recognizes a title
- **THEN** `AgentTitleDetection.detect(_:)` MUST return `nil`
- **AND** `AgentTitleDetection.stripPrefix(_:)` MUST return `nil`

### Requirement: Claude Code title detection
The system SHALL detect Claude Code activity via terminal titles whose first Unicode scalar is a Braille Patterns character (U+2800–U+28FF), `✳` (U+2733), or ASCII `*`. Braille glyphs MUST map to `.thinking`, and `✳` or `*` MUST map to `.idle`.

#### Scenario: Braille spinner indicates thinking
- **WHEN** a title begins with any character in U+2800–U+28FF
- **THEN** the Claude detector returns `.thinking`

#### Scenario: Eight-spoked asterisk indicates idle
- **WHEN** a title begins with `✳` (U+2733)
- **THEN** the Claude detector returns `.idle`

#### Scenario: ASCII asterisk indicates idle
- **WHEN** a title begins with `*`
- **THEN** the Claude detector returns `.idle`

#### Scenario: Prefix stripping removes indicator and leading space
- **WHEN** `stripPrefix("⠋ Thinking…")` is called
- **THEN** the result is `"Thinking…"`

### Requirement: Gemini CLI title detection
The system SHALL detect Gemini CLI activity via terminal titles whose first Unicode scalar is one of: `◇` (U+25C7) for idle, `✦` (U+2726) or `⏲` (U+23F2) for thinking, or `✋` (U+270B) for needs-attention. The detector MUST trim trailing whitespace (Gemini pads titles to 80 characters).

#### Scenario: Diamond indicates idle
- **WHEN** a title begins with `◇`
- **THEN** the Gemini detector returns `.idle`

#### Scenario: Four-pointed star indicates thinking
- **WHEN** a title begins with `✦`
- **THEN** the Gemini detector returns `.thinking`

#### Scenario: Timer indicates thinking
- **WHEN** a title begins with `⏲`
- **THEN** the Gemini detector returns `.thinking`

#### Scenario: Raised hand indicates needs attention
- **WHEN** a title begins with `✋`
- **THEN** the Gemini detector returns `.needsAttention`

#### Scenario: Prefix stripping handles Gemini's two-space separator and trailing padding
- **WHEN** `stripPrefix("◇  Ready (my-folder)" + padding)` is called
- **THEN** the result is `"Ready (my-folder)"` with trailing padding trimmed

### Requirement: OpenAI Codex CLI title detection
The system SHALL detect OpenAI Codex CLI activity via terminal titles whose first Unicode scalar is a Braille Patterns character (U+2800–U+28FF), returning `.thinking`. Codex has no idle or needs-attention glyph; those states MUST fall through to the title-change handler's implicit-idle branch.

#### Scenario: Braille spinner indicates thinking
- **WHEN** a title begins with any character in U+2800–U+28FF
- **THEN** the Codex detector returns `.thinking`

#### Scenario: No idle glyph
- **WHEN** a Codex title has no Braille prefix (e.g. `"my-project"`)
- **THEN** the Codex detector returns `nil`

### Requirement: Pane agent session field
The `Pane` model SHALL store the agent-session reference in a field named `agentSessionID: String?`. The legacy `claudeSessionID` field MUST be removed from the model while remaining readable as a fallback during Codable decoding of older workspace files.

#### Scenario: New panes initialize with no agent session
- **WHEN** a new `Pane` is created without specifying an agent session
- **THEN** `agentSessionID` is `nil`

#### Scenario: Legacy workspace files decode successfully
- **WHEN** a workspace file containing `"claudeSessionID": "auto"` is decoded
- **THEN** the resulting `Pane.agentSessionID` equals `"auto"`

#### Scenario: New workspace files encode under the new key
- **WHEN** a `Pane` with `agentSessionID = "auto"` is encoded
- **THEN** the output contains `"agentSessionID": "auto"` and MUST NOT contain `"claudeSessionID"`

### Requirement: Title-change handler routes agent presence
`PaneEventHandler.handleTitleChange` SHALL consult `AgentTitleDetection.detect(_:)` on every title change and update the pane's `isThinking`, `attentionKind`, and `agentSessionID` fields according to the returned presence.

#### Scenario: Thinking presence sets isThinking and clears attention
- **WHEN** `AgentTitleDetection.detect(_:)` returns `.thinking`
- **THEN** `pane.isThinking` is set to `true`
- **AND** `pane.attentionKind` is set to `nil`
- **AND** `pane.agentSessionID` is set to `"auto"` if previously `nil`

#### Scenario: Idle presence ends thinking
- **WHEN** `AgentTitleDetection.detect(_:)` returns `.idle`
- **THEN** the handler invokes the existing `endThinking` logic (which sets `.done` attention if the pane was thinking and is currently unfocused)
- **AND** `pane.agentSessionID` is set to `"auto"` if previously `nil`

#### Scenario: Needs-attention only fires attention when pane is unfocused
- **WHEN** `AgentTitleDetection.detect(_:)` returns `.needsAttention`
- **AND** the pane is not the focused pane of the selected workspace
- **THEN** `pane.isThinking` is set to `false`
- **AND** `pane.attentionKind` is set to `.done`

#### Scenario: Needs-attention does not fire attention when pane is focused
- **WHEN** `AgentTitleDetection.detect(_:)` returns `.needsAttention`
- **AND** the pane is the focused pane of the selected workspace
- **THEN** `pane.isThinking` is set to `false`
- **AND** `pane.attentionKind` is left unchanged

### Requirement: Implicit idle branch for agents without idle glyphs
When a pane currently has `agentSessionID == "auto"` and `isThinking == true`, and a title change is received that does NOT match any registered detector, `PaneEventHandler.handleTitleChange` SHALL treat the transition as an implicit idle: invoke `endThinking`, preserve the `agentSessionID` marker, and leave the pane otherwise unchanged.

#### Scenario: Codex thinking → idle transition
- **GIVEN** a pane with `agentSessionID == "auto"` and `isThinking == true` (set by a previous Braille title)
- **WHEN** the title changes to one with no agent prefix (e.g. `"my-project"`)
- **THEN** `endThinking` is invoked
- **AND** `pane.agentSessionID` remains `"auto"`
- **AND** the attention kind becomes `.done` if the pane is currently unfocused

#### Scenario: Non-agent pane ignores unmatched titles
- **GIVEN** a pane with `agentSessionID == nil`
- **WHEN** the title changes to one with no agent prefix
- **THEN** no pane state changes

#### Scenario: Process exit clears session marker
- **WHEN** `processDidExit` fires for a pane
- **THEN** `pane.agentSessionID` is set to `nil`
- **AND** `pane.isThinking` is set to `false`

### Requirement: Tool-agnostic attention label
The `AttentionKind.done` case SHALL display as `"Agent Done"` (previously `"Claude Done"`) to reflect tool-agnostic coverage.

#### Scenario: Display name
- **WHEN** `AttentionKind.done.displayName` is read
- **THEN** the result is `"Agent Done"`

### Requirement: Status indicator parameter rename
`StatusDotView` SHALL expose its agent-session indicator as a parameter named `isAgentSession` (previously `isClaudeSession`). All call sites MUST be updated accordingly.

#### Scenario: Parameter usage
- **WHEN** a view constructs a `StatusDotView` for a pane with `agentSessionID != nil`
- **THEN** it passes `isAgentSession: true`
