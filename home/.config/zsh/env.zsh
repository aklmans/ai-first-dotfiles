# Shared shell environment.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

export AI_PROVIDER="claude"
export AI_MODEL="sonnet"

export GO111MODULE=on
export GOPROXY="https://goproxy.cn"
export GOPATH="$HOME/.local/share/go"
export GOBIN="$GOPATH/bin"
unset GOSRC GOPKG

# export RUSTUP_DIST_SERVER="https://rsproxy.cn/rustup"
# export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
export RUSTUP_DIST_SERVER="https://static.rust-lang.org"
export RUSTUP_UPDATE_ROOT="https://static.rust-lang.org/rustup"

export BUN_INSTALL="$HOME/.bun"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="arc"

export LDFLAGS="-L/opt/homebrew/opt/php/lib"
export CPPFLAGS="-I/opt/homebrew/opt/php/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig"

typeset -gU path
path=(
  "$HOME/.local/bin"
  "$GOBIN"
  "$HOME/.console-ninja/.bin"
  /opt/homebrew/opt/file-formula/bin
  "$BUN_INSTALL/bin"
  "$HOME/.config/composer/vendor/bin"
  /opt/homebrew/opt/php/bin
  /opt/homebrew/opt/php/sbin
  /opt/homebrew/bin
  /opt/homebrew/sbin
  "$HOME/.openclaw/bin"
  "$HOME/.cargo/bin"
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
  $path
)

# Remove stale paths from retired toolchains so parent environments cannot
# reintroduce them into fresh shells.
path=(${path:#$HOME/.local/share/zinit/polaris/bin})
path=(${path:#/opt/homebrew/opt/openjdk@17/bin})
path=(${path:#$HOME/.rbenv/shims})
path=(${path:#$HOME/.rbenv/bin})
path=(${path:#$HOME/.nvm/versions/node/*/bin})

export PATH

# Local/private overrides and secrets.
[[ -f "$ZDOTDIR/private.zsh" ]] && source "$ZDOTDIR/private.zsh"
