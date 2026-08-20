# Hootty hook helper — resolve the device to write OSC sequences to.
# Sourced by the agent hook scripts; sets HOOTTY_OSC_TTY.
#
# Hooks cannot simply write to /dev/tty. Claude Code 2.x runs hook commands
# detached from the controlling terminal — `tty` reports "not a tty" and
# opening /dev/tty fails with ENXIO — so every OSC written that way is
# silently dropped. Addressing the pane's PTY by path still works: writing to
# the slave device reaches ghostty's parser exactly like stdout would.
#
# Resolution order:
#   1. The controlling terminal of the agent process that spawned us ($PPID).
#      Always current, and correct even when the environment was inherited
#      from another pane.
#   2. HOOTTY_TTY — exported by Hootty's shell integration for this pane.
#      Covers parents that have no controlling terminal of their own.
#   3. /dev/tty, for hooks that do still keep a controlling terminal.
_hootty_resolve_tty() {
    local candidate
    candidate="$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d '[:space:]')"
    case "$candidate" in
        ''|'??'|'-') ;;
        *)
            candidate="/dev/$candidate"
            if [ -c "$candidate" ] && [ -w "$candidate" ]; then
                printf '%s' "$candidate"
                return 0
            fi
            ;;
    esac
    if [ -n "$HOOTTY_TTY" ] && [ -c "$HOOTTY_TTY" ] && [ -w "$HOOTTY_TTY" ]; then
        printf '%s' "$HOOTTY_TTY"
        return 0
    fi
    printf '/dev/tty'
}

HOOTTY_OSC_TTY="$(_hootty_resolve_tty)"
