# Core environment first so every later command sees the final PATH.
[[ -f "$ZDOTDIR/env.zsh" ]] && source "$ZDOTDIR/env.zsh"
[[ -f "$HOME/.config/kaku/zsh/kaku.zsh" ]] && source "$HOME/.config/kaku/zsh/kaku.zsh"
[[ -f "$ZDOTDIR/plugins.zsh" ]] && source "$ZDOTDIR/plugins.zsh"
[[ -f "$ZDOTDIR/aliases.zsh" ]] && source "$ZDOTDIR/aliases.zsh"
# Your own aliases, right after the shipped set so they win over it. Never
# tracked, never deployed; start one from aliases.local.zsh.example.
[[ -f "$ZDOTDIR/aliases.local.zsh" ]] && source "$ZDOTDIR/aliases.local.zsh"
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"

# personal.zsh used to be shipped by this repo: an empty file, tracked in git,
# deployed over whatever anyone had written into it. It is no longer shipped or
# deployed. One that still has content keeps working, with a pointer to the file
# this repo will never write to.
if [[ -s "$ZDOTDIR/personal.zsh" ]]; then
  source "$ZDOTDIR/personal.zsh"
  if [[ -o interactive ]]; then
    printf 'note: %s/personal.zsh is no longer part of this repo.\n' "$ZDOTDIR" >&2
    printf '      Rename it to private.zsh, which is never tracked or deployed.\n' >&2
  fi
fi

# Machine-local overrides and secrets, last so they win over everything above.
# Never tracked, never deployed: copy private.zsh.example to start one.
if [[ -f "$ZDOTDIR/private.zsh" ]]; then
  source "$ZDOTDIR/private.zsh"
fi
