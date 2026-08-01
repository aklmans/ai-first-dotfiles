# Shared shell environment.
#
# Nothing here is unconditional. A PATH entry that does not exist on this
# machine is not added, and a tool's variables are set only when that tool is
# installed - every line in this file runs in every shell, and a directory named
# for someone else's toolchain is at best noise and at worst a compiler flag
# pointing at headers that are not there.
#
# Machine-specific values belong in private.zsh, which is sourced last and is
# never tracked or deployed. See private.zsh.example.

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# --- toolchains -------------------------------------------------------------
#
# Package-manager mirrors (Go, pub/Flutter, npm, rustup, PyPI) are deliberately
# not set here. Redirecting where somebody else's toolchain downloads from is
# not a default a dotfiles repo gets to pick for them: it is invisible, it
# changes what code lands on the machine, and outside the one region it was
# chosen for it is slower, not faster. Set yours in private.zsh instead.

export GO111MODULE=on
export GOPATH="$HOME/.local/share/go"
export GOBIN="$GOPATH/bin"
unset GOSRC GOPKG

export BUN_INSTALL="$HOME/.bun"

# The first of these that exists wins. Leaving EDITOR pointing at an editor the
# machine does not have breaks `git commit`, `crontab -e` and everything else
# that honours it, with an error naming the editor rather than the cause.
for _ai_first_editor in nvim vim vi; do
  if command -v "$_ai_first_editor" >/dev/null 2>&1; then
    export EDITOR="$_ai_first_editor"
    export VISUAL="$_ai_first_editor"
    break
  fi
done
unset _ai_first_editor

# BROWSER is deliberately unset. This config used to export `arc`, which is not
# a command any Arc install provides, so every tool that honoured it failed
# looking for it. macOS routes URLs through `open` and the default browser you
# already picked; set BROWSER in private.zsh only if some tool insists on it.

# --- PATH -------------------------------------------------------------------

typeset -gU path
typeset -ga _ai_first_path

# Collects the directories that are actually here, in the order given, so the
# resulting PATH is both correct and free of entries that only ever existed on
# the machine this file grew up on.
_ai_first_path_add() {
  local dir
  for dir in "$@"; do
    [[ -d "$dir" ]] && _ai_first_path+=("$dir")
  done
}

_ai_first_path=()
_ai_first_path_add \
  "$HOME/.local/bin" \
  "$GOBIN" \
  "$BUN_INSTALL/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/.config/composer/vendor/bin" \
  /opt/homebrew/opt/php/bin \
  /opt/homebrew/opt/php/sbin \
  /opt/homebrew/bin \
  /opt/homebrew/sbin \
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

path=($_ai_first_path $path)

unset _ai_first_path
unfunction _ai_first_path_add

# Remove stale paths from retired toolchains so a parent environment cannot
# reintroduce them into fresh shells.
path=(${path:#$HOME/.local/share/zinit/polaris/bin})
path=(${path:#/opt/homebrew/opt/openjdk@17/bin})
path=(${path:#$HOME/.rbenv/shims})
path=(${path:#$HOME/.rbenv/bin})
path=(${path:#$HOME/.nvm/versions/node/*/bin})

export PATH

# Build flags for Homebrew PHP and OpenSSL used to be exported here without a
# guard. They apply to every compile in every shell, not just to PHP extensions,
# which is not something this repo should decide for anyone. private.zsh.example
# has them ready to uncomment.

# private.zsh is sourced at the end of .zshrc rather than here, so an override in
# it wins over the aliases and functions loaded after this file instead of being
# undone by them.
