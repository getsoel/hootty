# Configuration System

All app settings live in a single file: `~/Library/Application Support/Hootty/config` (debug: `Hootty-Dev/config`).

## File Format

Plain text, one `key = value` per line. Comments with `#`. Same format as ghostty config.

```
# Ghostty settings
theme = catppuccin-mocha
font-size = 14

# Hootty settings
hootty-bell-sound = Ping
hootty-attention-idle-sound = Submarine
```

## Key Naming

- **Ghostty-native keys** use plain names: `theme`, `font-size`, `cursor-style`, etc. These are passed through to ghostty as-is.
- **Hootty-specific keys** use the `hootty-` prefix: `hootty-bell-sound`, `hootty-attention-idle-sound`, etc. These are filtered out before feeding config to ghostty.

## Repeatable Keys

Some ghostty keys (like `font-family`) support multiple values — each line adds a fallback. Hootty preserves these: `ghosttyConfigContent()` reads the raw file from disk (rather than reconstructing from a dictionary), and `save()` only rewrites keys that were changed via `set()`. All other lines pass through verbatim.

Example font configuration:
```
font-family = JetBrains Mono
font-family = Apple Symbols
```
The first line sets the primary font; the second adds a fallback for symbols not covered by the primary font. The default config includes `Menlo` (ghostty's macOS default) and `Apple Symbols` (covers Unicode symbols like ➜).

## Adding a New Setting

1. **Choose the key name.** If ghostty owns it, use the ghostty key name. If it's Hootty-only, prefix with `hootty-`.
2. **Read/write through ConfigFile.** Use `configFile.get("key")` and `configFile.set("key", value:)` + `configFile.save()`. Never use UserDefaults or separate files.
3. **Inject ConfigFile via init.** Your manager/model should accept `ConfigFile` as an init parameter (see `ThemeManager`, `SoundManager`).
4. **Add a default comment** to `ConfigFile.defaultConfigContent()` if the setting should be discoverable in new config files.

## Architecture

```
ConfigFile (@Observable, HoottyCore)
  ├── ThemeManager — reads/writes `theme`
  ├── SoundManager — reads/writes `hootty-bell-sound`, `hootty-attention-*-sound`
  └── ghosttyConfigContent() — filters out `hootty-` keys → written to cache file for ghostty
```

`AppModel` creates the shared `ConfigFile` instance and injects it into managers. `GhosttyApp` reads the filtered content for ghostty config.

## Migration

On first launch, `ensureExists()` migrates from the old format (separate `ghostty.config` + UserDefaults for theme) into the unified file, then deletes the old files.
