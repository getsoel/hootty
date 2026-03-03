---
globs: Sources/Klaude/PTY/**/*.swift
---
All Swift string-to-C conversions must happen BEFORE `forkpty()`. The child process must only call async-signal-safe functions: `chdir`, `execve`, `_exit`. Never call Swift runtime functions, allocate memory, or use Foundation APIs in the child path.
