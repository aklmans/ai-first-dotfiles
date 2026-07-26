# Shared shell environment.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Package-manager mirrors (Go, pub/Flutter, npm, rustup, PyPI) are deliberately
# not set here. Redirecting where somebody else's toolchain downloads from is
# not a default a dotfiles repo gets to pick for them: it is invisible, it
# changes what code lands on the machine, and outside the one region it was
# chosen for it is slower, not faster. Set yours in private.zsh instead;
# private.zsh.example has the ones this repo used to hard-code.
export GO111MODULE=on
export GOPATH="$HOME/.local/share/go"
export GOBIN="$GOPATH/bin"
unset GOSRC GOPKG

export RUSTUP_DIST_SERVER="https://static.rust-lang.org"
export RUSTUP_UPDATE_ROOT="https://static.rust-lang.org/rustup"

export BUN_INSTALL="$HOME/.bun"

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

# private.zsh used to be sourced from here. It is now the last thing .zshrc
# does, so an override in it wins over every file this repo ships rather than
# being undone by the aliases and functions loaded after this one.
