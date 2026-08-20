# Hootty zsh integration — keep Hootty's wrapper bin dir at the front of PATH.
#
# Hootty seeds PATH with its bin dir when it spawns the shell, but the user's
# rc files run afterwards and routinely prepend their own dirs (a plain
# `export PATH="$HOME/.local/bin:$PATH"` in .zshenv is enough). Claude Code's
# native installer lives in ~/.local/bin, so that one line silently shadows
# Hootty's `claude` wrapper and every hook it injects — presence, resume, cwd.
#
# Re-asserting the position on each prompt is what makes the wrappers reliable:
# rc files, direnv, version managers and friends all get to run first, and the
# wrapper still wins for the command the user actually types.
#
# Sourced from ../zsh/.zshenv. No-ops outside Hootty (HOOTTY_BIN_DIR unset).

if [[ -n "$HOOTTY_BIN_DIR" ]]; then
    # Agent CLIs run their hooks detached from the controlling terminal, so a
    # hook cannot open /dev/tty to talk back to Hootty. Publish this pane's PTY
    # by path as the fallback channel (see bin/hootty-tty.sh).
    if [[ -c "$TTY" ]]; then
        'builtin' 'export' HOOTTY_TTY="$TTY"
    fi

    _hootty_prepend_bin() {
        # Steady state is a single string compare — this runs every prompt.
        [[ "$path[1]" == "$HOOTTY_BIN_DIR" ]] && return 0
        path=("$HOOTTY_BIN_DIR" ${path:#$HOOTTY_BIN_DIR})
    }

    builtin typeset -ag precmd_functions
    if [[ -z "${precmd_functions[(r)_hootty_prepend_bin]}" ]]; then
        precmd_functions+=(_hootty_prepend_bin)
    fi
fi
