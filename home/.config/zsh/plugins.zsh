# Completion directories: autoload on demand instead of sourcing large scripts up front.
typeset -gU fpath
fpath=(
  "$ZDOTDIR/completions"
  "$HOME/.bun"
  "$HOME/.docker/completions"
  /opt/homebrew/share/zsh/site-functions
  $fpath
)

# Rebuild the completion cache only when something in fpath is newer than it.
# This used to name two specific completion files as the staleness trigger, so
# adding any third one left the cache stale until it was deleted by hand. The
# glob asks the question directly: is there a completion file newer than the
# dump? (N) keeps an empty match from erroring under `set -u`.
autoload -Uz compinit
_zcompdump="$ZDOTDIR/.zcompdump"

# The newest completion file anywhere in fpath: (N) nullglob, (.) regular files,
# (om) newest first, [1] just that one.
_zcomp_newest=(${^fpath}/_*(N.om[1]))

if [[ ! -s "$_zcompdump" ]] || [[ -n "$_zcomp_newest" && "$_zcomp_newest[1]" -nt "$_zcompdump" ]]; then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
unset _zcompdump _zcomp_newest

if [[ -z "${KAKU_ZSH_DIR:-}" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

[[ -f "$ZDOTDIR/codex-widget.zsh" ]] && source "$ZDOTDIR/codex-widget.zsh"
