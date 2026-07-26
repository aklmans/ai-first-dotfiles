# Proxy toggles. No endpoint is hard-coded: a port that happens to be right on
# the machine this repo grew up on is a silent misconfiguration everywhere else.
# Export PROXY_URL (and PROXY_SOCKS_URL if your proxy also speaks SOCKS) in
# ~/.config/zsh/private.zsh; private.zsh.example shows the usual shape.
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

# Navigation aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"
alias home="cd ~"

# Workspace roots (can be overridden locally).
: "${WORKFLOW_WORKSPACE_DIR:=$HOME/Workspace}"
: "${WORKFLOW_PROJECTS_DIR:=$WORKFLOW_WORKSPACE_DIR/Projects}"
: "${WORKFLOW_DIR:=$WORKFLOW_PROJECTS_DIR/workflow}"
# This repository's own checkout, defaulting to where `git clone` puts it under
# the projects root. Set DOTFILES_DIR in private.zsh if yours lives elsewhere.
: "${DOTFILES_DIR:=$WORKFLOW_PROJECTS_DIR/ai-first-dotfiles}"
: "${GBRAIN_DIR_LOCAL:=${XDG_DATA_HOME:-$HOME/.local/share}/gbrain}"

# Directory aliases
alias workspace="cd $WORKFLOW_WORKSPACE_DIR"
alias projects="cd $WORKFLOW_PROJECTS_DIR"
alias codes="cd $WORKFLOW_PROJECTS_DIR"
alias sites="cd $WORKFLOW_PROJECTS_DIR"
alias workflow="cd $WORKFLOW_DIR"
alias gbrainp="cd $GBRAIN_DIR_LOCAL"
alias gopath="cd $HOME/.local/share/go"
alias gobin="cd $GOBIN"
alias localbin="cd $HOME/.local/bin"
alias odw="cd $HOME/Downloads && open ."
alias dw="cd $HOME/Downloads"

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

# PHP aliases
alias art='php artisan '
alias phpunit='./vendor/bin/phpunit'
alias pest='./vendor/bin/pest'
alias sail="./vendor/bin/sail "

# Application aliases
alias typora='open -a Typora.app'
alias edge='open -a "Microsoft Edge"'

# Database aliases
alias redis='redis-cli'
alias mysqll='mysql -uroot -p'

# Utility aliases
alias ip='curl ipinfo.io'

# VSCode alias
alias vs='code'

# Vim aliases
alias vi="nvim"
alias vim="nvim"

# Git and Docker aliases
alias lg='lazygit'
alias lzd='lazydocker'

# File listing aliases. macOS ships BSD ls, which has no --all and no --tree at
# all, so those two are defined only when something that understands them is
# installed. -A is the flag both BSD and GNU ls accept.
alias ll='ls -alF'
alias lsa='ls -A'
if command -v eza >/dev/null 2>&1; then
  alias lsa='eza --all'
  alias lst='eza --tree'
elif command -v tree >/dev/null 2>&1; then
  alias lst='tree'
fi

# System update aliases
alias upgrade="sudo softwareupdate -i -a; brew update; brew upgrade; brew cleanup; npm install npm -g; npm update -g"
alias update='brew update; brew upgrade --greedy-auto-updates; brew cleanup --prune=all; mas upgrade;npm install npm -g; npm update -g'
alias updates='topgrade --dry-run'
alias upall='topgrade'

# Finder aliases
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# System cleanup placeholder. Put machine-specific destructive cleanup in
# ~/.config/zsh/private.zsh if you need it.
emptytrash() {
  printf 'emptytrash is disabled in the public config; use Finder or a private override.\n' >&2
  return 64
}

# Utility aliases
alias path='print -l ${(s/:/)PATH}'
alias hosts='sudo vim /etc/hosts'
alias cwd='pwd | tr -d "\r\n" | pbcopy'
alias cp='cp -i'
alias mv='mv -i'
alias mkd='mkdir -p'
alias untar='tar xvf'
alias c='clear'
alias q='exit'

# Python aliases
alias jnb='jupyter notebook'

# Sketchybar Service
alias skp='brew services stop felixkratz/formulae/sketchybar'
alias skt='brew services start felixkratz/formulae/sketchybar'

# AI Service
alias cc='claude'
alias gm='gemini'
alias km='kimi'
alias jn='junie'
