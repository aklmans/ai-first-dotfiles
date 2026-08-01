# Aliases that make sense on any Mac.
#
# Anything tied to one person's projects, editors, database or app choices lives
# in aliases.local.zsh, which this repo ships only as an example and never
# deploys over. An alias whose tool is optional is defined only when that tool is
# installed: a shell full of names that fail with "command not found" is worse
# than not having them.

# --- proxy ------------------------------------------------------------------
# No endpoint is hard-coded: a port that happens to be right on the machine this
# repo grew up on is a silent misconfiguration everywhere else. Export PROXY_URL
# (and PROXY_SOCKS_URL if your proxy also speaks SOCKS) in private.zsh.
proxy() {
  local http_url="${PROXY_URL:-}"
  local socks_url="${PROXY_SOCKS_URL:-$PROXY_URL}"

  if [[ -z "$http_url" ]]; then
    printf 'proxy: no proxy configured. Put this in ~/.config/zsh/private.zsh:\n' >&2
    printf '  export PROXY_URL="http://127.0.0.1:<your proxy port>"\n' >&2
    return 64
  fi

  export http_proxy="$http_url"
  export https_proxy="$http_url"
  export all_proxy="$socks_url"
  export no_proxy="localhost,127.0.0.1,::1"
}

unproxy() {
  unset all_proxy http_proxy https_proxy no_proxy
}

# --- navigation -------------------------------------------------------------
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias home="cd ~"

# This repository's own checkout. Set DOTFILES_DIR in private.zsh if yours lives
# somewhere other than the default clone location.
: "${DOTFILES_DIR:=$HOME/Workspace/Projects/ai-first-dotfiles}"

# A function rather than an alias so a checkout somewhere else says what to fix
# instead of failing with a bare "no such file or directory".
dotfiles() {
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    printf 'dotfiles: %s does not exist.\n' "$DOTFILES_DIR" >&2
    printf 'Set DOTFILES_DIR to your checkout in ~/.config/zsh/private.zsh.\n' >&2
    return 66
  fi
  cd "$DOTFILES_DIR"
}

# --- files ------------------------------------------------------------------
# macOS ships BSD ls, which has neither --all nor --tree. -A is the one flag
# both BSD and GNU accept.
alias ll='ls -alF'
alias lsa='ls -A'
if command -v eza >/dev/null 2>&1; then
  alias lsa='eza --all'
  alias lst='eza --tree'
elif command -v tree >/dev/null 2>&1; then
  alias lst='tree'
fi

alias cp='cp -i'
alias mv='mv -i'
alias mkd='mkdir -p'
alias untar='tar xvf'

# --- shell ------------------------------------------------------------------
alias c='clear'
alias q='exit'
alias path='print -l ${(s/:/)PATH}'
alias cwd='pwd | tr -d "\r\n" | pbcopy'

# $EDITOR rather than a named editor: env.zsh already picked the first one this
# machine actually has.
alias hosts='sudo $EDITOR /etc/hosts'

if command -v nvim >/dev/null 2>&1; then
  alias vi='nvim'
  alias vim='nvim'
fi

# --- macOS ------------------------------------------------------------------
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"
alias ip='curl ipinfo.io'

# Kept as a stub on purpose. This name used to be an alias that emptied the
# Trash without asking, which is not something a shell config should hand a
# stranger by default.
emptytrash() {
  printf 'emptytrash is disabled in the public config; use Finder or a private override.\n' >&2
  return 64
}

# --- development ------------------------------------------------------------
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'
command -v lazydocker >/dev/null 2>&1 && alias lzd='lazydocker'

# One maintenance alias, not four. `mas` joins the chain only when it is
# installed, since a missing App Store CLI would otherwise fail the whole run.
if command -v mas >/dev/null 2>&1; then
  alias update='brew update && brew upgrade && brew cleanup && mas upgrade'
else
  alias update='brew update && brew upgrade && brew cleanup'
fi

# --- your own ---------------------------------------------------------------
# aliases.local.zsh is sourced by .zshrc when it exists, and is never tracked or
# deployed. Start one from the example next to this file:
#
#     cp ~/.config/zsh/aliases.local.zsh.example ~/.config/zsh/aliases.local.zsh
