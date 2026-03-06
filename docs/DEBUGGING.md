# Debugging

All runtime logging uses Apple's Unified Logging (`os.Logger`) with subsystem `com.soel.hootty`.

```bash
# Tail live logs while app runs (in a separate terminal):
log stream --predicate 'subsystem == "com.soel.hootty"' --level debug

# View recent logs after a crash:
log show --predicate 'subsystem == "com.soel.hootty"' --last 5m --style compact

# Filter by category (ghostty, surface, lifecycle, crash):
log show --predicate 'subsystem == "com.soel.hootty" AND category == "ghostty"' --last 5m

# Check crash log:
cat ~/Library/Logs/Hootty/crash.log

# Run with stderr visible:
swift run Hootty 2>&1 | tee /tmp/hootty-stderr.log
```
