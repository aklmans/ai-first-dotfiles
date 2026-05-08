# Proxy aliases
alias proxy='export all_proxy=socks5://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 no_proxy=localhost,127.0.0.1,::1'
alias unproxy='unset all_proxy http_proxy https_proxy no_proxy'

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
: "${DOTFILES_DIR:=$WORKFLOW_DIR/ai-first-dotfile}"
: "${GBRAIN_DIR_LOCAL:=${XDG_DATA_HOME:-$HOME/.local/share}/gbrain}"

# Directory aliases
alias workspace="cd $WORKFLOW_WORKSPACE_DIR"
alias projects="cd $WORKFLOW_PROJECTS_DIR"
alias codes="cd $WORKFLOW_PROJECTS_DIR"
alias sites="cd $WORKFLOW_PROJECTS_DIR"
alias workflow="cd $WORKFLOW_DIR"
alias dotfiles="cd $DOTFILES_DIR"
alias gbrainp="cd $GBRAIN_DIR_LOCAL"
alias gopath="cd $HOME/.local/share/go"
alias gobin="cd $GOBIN"
alias localbin="cd $HOME/.local/bin"
alias odw="cd $HOME/Downloads && open ."
alias dw="cd $HOME/Downloads"

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

# JetBrains IDE aliases
alias gl="$HOME/.jetbrains/gl"
alias wb="$HOME/.jetbrains/web"
alias ide="$HOME/.jetbrains/idea"
alias it="$HOME/.jetbrains/idea"
alias ph="$HOME/.jetbrains/ps"
alias rr="$HOME/.jetbrains/rr"

# VSCode alias
alias vs='code'

# Vim aliases
alias vi="nvim"
alias vim="nvim"

# Git and Docker aliases
alias lg='lazygit'
alias lzd='lazydocker'

# File listing aliases
alias ll='ls -alF'
alias lsa='ls --all'
alias lst='ls --tree'

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
