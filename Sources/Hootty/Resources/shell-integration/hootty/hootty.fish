# Hootty fish integration — keep Hootty's wrapper bin dir at the front of PATH.
#
# See hootty.zsh for why this is needed: Hootty seeds PATH before the shell
# starts, the user's config runs afterwards and prepends over it, and Claude
# Code's native install in ~/.local/bin ends up shadowing Hootty's `claude`
# wrapper along with the hooks it injects.
#
# Sourced from ../fish/vendor_conf.d/ghostty-shell-integration.fish.
# No-ops outside Hootty (HOOTTY_BIN_DIR unset).

# Agent CLIs run their hooks detached from the controlling terminal, so a hook
# cannot open /dev/tty to talk back to Hootty. Publish this pane's PTY by path
# as the fallback channel (see bin/hootty-tty.sh).
if test -n "$HOOTTY_BIN_DIR"
    set --local __hootty_tty (tty 2>/dev/null)
    test -c "$__hootty_tty"; and set -gx HOOTTY_TTY $__hootty_tty
end

function __hootty_prepend_bin --on-event fish_prompt -d "Keep Hootty's bin dir first in PATH"
    test -n "$HOOTTY_BIN_DIR"; or return 0
    # Steady state is a single string compare — this runs every prompt.
    test "$PATH[1]" = "$HOOTTY_BIN_DIR"; and return 0
    set -gx PATH $HOOTTY_BIN_DIR (string match --invert -- "$HOOTTY_BIN_DIR" $PATH)
end
