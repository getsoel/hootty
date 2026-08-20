# Hootty bash integration — keep Hootty's wrapper bin dir at the front of PATH.
#
# See hootty.zsh for why this is needed: Hootty seeds PATH before the shell
# starts, the user's rc files prepend over it, and Claude Code's native install
# in ~/.local/bin ends up shadowing Hootty's `claude` wrapper along with the
# hooks it injects.
#
# Sourced from ../bash/ghostty.bash. No-ops outside Hootty (HOOTTY_BIN_DIR unset).

if [ -n "$HOOTTY_BIN_DIR" ]; then
  # Agent CLIs run their hooks detached from the controlling terminal, so a
  # hook cannot open /dev/tty to talk back to Hootty. Publish this pane's PTY
  # by path as the fallback channel (see bin/hootty-tty.sh).
  if [ -t 0 ]; then
    __hootty_tty="$(tty 2>/dev/null)"
    if [ -c "$__hootty_tty" ]; then builtin export HOOTTY_TTY="$__hootty_tty"; fi
    builtin unset __hootty_tty
  fi

  __hootty_prepend_bin() {
    # Steady state is a single prefix compare — this runs every prompt.
    case "$PATH" in
      "$HOOTTY_BIN_DIR":*) return 0 ;;
    esac
    builtin local rest=":$PATH:"
    rest="${rest//:$HOOTTY_BIN_DIR:/:}"
    rest="${rest#:}"
    rest="${rest%:}"
    if [ -n "$rest" ]; then
      PATH="$HOOTTY_BIN_DIR:$rest"
    else
      PATH="$HOOTTY_BIN_DIR"
    fi
  }

  # bash-preexec owns PROMPT_COMMAND when it is loaded, so hook its array
  # instead; otherwise append to PROMPT_COMMAND the way ghostty.bash does.
  if [ -n "${__bp_imported:-}" ]; then
    precmd_functions+=(__hootty_prepend_bin)
  elif [[ "${PROMPT_COMMAND[*]:-}" != *"__hootty_prepend_bin"* ]]; then
    if [ -z "${PROMPT_COMMAND[*]}" ]; then
      if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        PROMPT_COMMAND=(__hootty_prepend_bin)
      else
        # shellcheck disable=SC2178
        PROMPT_COMMAND="__hootty_prepend_bin"
      fi
    elif [[ $(builtin declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a "* ]]; then
      PROMPT_COMMAND+=(__hootty_prepend_bin)
    else
      # shellcheck disable=SC2179
      PROMPT_COMMAND+="; __hootty_prepend_bin"
    fi
  fi
fi
