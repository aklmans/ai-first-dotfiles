# Keyboard launcher for Codex interactive sessions: turns whatever is on the
# command line into the prompt for a `codex` session in the current directory.
#
# It binds nothing by default. This used to claim `Ctrl+X` and `Ctrl+]` in both
# emacs and vi insert keymaps, unasked - and `Ctrl+X` is zsh's standard emacs
# prefix key, the one in front of `Ctrl+X Ctrl+E` (edit the command line in
# $EDITOR), `Ctrl+X Ctrl+B`, and the rest of that family. Taking a prefix key
# does not shadow one shortcut, it removes a whole set, and nothing said so.
#
# To turn it on, put a key in private.zsh:
#
#     CODEX_WIDGET_KEY='^]'        # Ctrl+]
#     CODEX_WIDGET_KEY='^X^G'      # a Ctrl+X sequence, leaving the prefix alone
#
# private.zsh is sourced after this file, so also call the binder yourself:
#
#     CODEX_WIDGET_KEY='^]'
#     codex_widget_bind
#
# Or bind the widget to anything you like: it is registered as
# `codex-widget-launch` whether or not a key points at it.

[[ -o interactive ]] || return 0

: "${CODEX_WIDGET_COMMAND:=${CODEX_CTRLX_COMMAND:-codex}}"

codex-widget-launch() {
  emulate -L zsh

  if ! command -v "$CODEX_WIDGET_COMMAND" >/dev/null 2>&1; then
    zle -M "codex-widget: command not found: $CODEX_WIDGET_COMMAND"
    return 1
  fi

  local prompt="$BUFFER"
  local cwd="$PWD"
  local command="${(q)CODEX_WIDGET_COMMAND} --cd ${(q)cwd}"

  if [[ -n "${prompt//[[:space:]]/}" ]]; then
    command+=" ${(q)prompt}"
  fi

  BUFFER="$command"
  CURSOR=${#BUFFER}
  zle accept-line
}

zle -N codex-widget-launch

# Binds CODEX_WIDGET_KEY in both keymaps. Safe to call more than once, and a
# no-op when no key has been chosen.
codex_widget_bind() {
  [[ -n "${CODEX_WIDGET_KEY:-}" ]] || return 0
  bindkey -M emacs "$CODEX_WIDGET_KEY" codex-widget-launch
  bindkey -M viins "$CODEX_WIDGET_KEY" codex-widget-launch
}

# Honours a key set before this file loads, e.g. exported from the environment.
codex_widget_bind
