# Zsh + Starship

This repository uses `zsh` as the primary shell environment, with `Starship` for prompt rendering.

## Installed files

- `home/.zshenv`
- `home/.config/zsh/.zshrc`
- `home/.config/zsh/.zprofile`
- `home/.config/zsh/env.zsh`
- `home/.config/zsh/plugins.zsh`
- `home/.config/zsh/aliases.zsh`
- `home/.config/zsh/functions.zsh`
- `home/.config/zsh/codex-widget.zsh`
- `home/.config/zsh/private.zsh.example`
- `home/.config/zsh/aliases.local.zsh.example`
- `home/.config/starship.toml`
- `bootstrap/install/zsh.sh`
- `bootstrap/install/starship.sh`

## Install

The shell layer is not part of `./bootstrap/setup.sh all`. It replaces the files
that decide how every shell on the machine starts, so it is asked for explicitly:

```bash
./bootstrap/setup.sh shell
```

or, for this module alone:

```bash
./bootstrap/install/zsh.sh
./bootstrap/install/starship.sh
```

## Before you install: what happens to your current `~/.zshrc`

`home/.zshenv` sets `ZDOTDIR="$HOME/.config/zsh"`. From the next shell on, zsh
reads `.zshrc`, `.zprofile` and `.zlogin` from that directory and **never opens
`~/.zshrc` again**. Your file is not deleted, not moved and not edited - it just
stops running, which is indistinguishable from a configuration that vanished.

So `bootstrap/install/zsh.sh` will not do that behind your back:

- If `~/.zshrc` exists, it explains the takeover and asks for confirmation.
- It copies your file to `~/.config/zsh/.zshrc.pre-dotfiles` first, so its
  content is still findable afterwards. That copy is written once and is never
  deployed over, and `bootstrap/uninstall.sh` leaves it alone.
- Without a terminal to answer on (CI, a pipeline, `zsh.sh | grep`), it does not
  block: it deploys everything else, leaves `~/.zshenv` alone so your shell keeps
  working, and exits 3.
- `--force` (or `DOTFILES_FORCE=1`) is how you say yes in advance.

Move whatever you want to keep from `.zshrc.pre-dotfiles` into
`~/.config/zsh/private.zsh`. To undo the takeover entirely, remove `~/.zshenv`
(or run `./bootstrap/uninstall.sh --apply`) and `~/.zshrc` is read again.

## Shell layout

`home/.zshenv` sets:

- `ZDOTDIR=$HOME/.config/zsh`

`home/.config/zsh/env.zsh` sets:

- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`
- Go/Bun/Rust locations, `EDITOR`, `PATH`

`home/.config/zsh/.zshrc` sources, in order:

- `env.zsh`
- Kaku integration (`~/.config/kaku/zsh/kaku.zsh`) when available
- `plugins.zsh`, `aliases.zsh`, `aliases.local.zsh`, `functions.zsh`
- `private.zsh`, last, so your overrides win

Nothing in `env.zsh`, `aliases.zsh` or `functions.zsh` is unconditional. A PATH
entry is added only when that directory exists, and an alias or function is
defined only when the tool behind it is installed — a shell full of names that
fail with "command not found" is worse than not having them. `EDITOR` is the
first of `nvim`, `vim`, `vi` that this machine actually has, rather than a fixed
name that breaks `git commit` when it is missing.

Two things are deliberately absent from the shipped files:

- **`kill` is not redefined.** This config used to shadow the builtin so a single
  non-numeric argument became `pkill -x`. Shadowing the command that ends
  processes, so that it does something its own manual page does not describe, is
  the wrong place to save four keystrokes. Use `pkill`.
- **`codex-widget.zsh` binds no key.** It used to claim `Ctrl+X`, which is zsh's
  emacs prefix key — the one in front of `Ctrl+X Ctrl+E` and the rest of that
  family — so it removed a whole set of shortcuts rather than one. Choose a key
  in `private.zsh`; see below.

## Starship

`home/.config/starship.toml` defines prompt sections, path/git/dir modules, and style.
If starship is absent, shell init falls back gracefully.

![Starship prompt](../../../assets/screenshots/starship-prompt.png)

## Local overrides: `private.zsh`

`~/.config/zsh/private.zsh` is where anything machine-specific belongs. It is
git-ignored, never deployed and never overwritten, and it is the last file
`.zshrc` sources, so it can override everything this repo ships.

```bash
cp ~/.config/zsh/private.zsh.example ~/.config/zsh/private.zsh
```

`private.zsh.example` lists what this repo deliberately does not set for you:

- a proxy endpoint for the `proxy` / `unproxy` helpers (`PROXY_URL`)
- package-manager mirrors (`GOPROXY`, `PUB_HOSTED_URL`, `RUSTUP_DIST_SERVER`, ...),
  which are off by default because silently changing where someone's toolchain
  downloads from is not a default a dotfiles repo gets to pick
- `DOTFILES_DIR`, when your checkout is not at the default location
- Homebrew PHP and OpenSSL build flags, which apply to every compile in every
  shell rather than only to PHP extensions
- a key for the Codex command-line widget (`CODEX_WIDGET_KEY`)
- launcher aliases for tools this repo does not install
- tokens and other secrets

## Your own aliases: `aliases.local.zsh`

`aliases.zsh` ships what makes sense on any Mac: navigation, file listing,
`$EDITOR`-based helpers, one Homebrew `update`. Anything naming a particular
project layout, database, editor or application lives in `aliases.local.zsh`,
which is git-ignored and never deployed, and which `.zshrc` sources right after
the shipped set so it wins.

```bash
cp ~/.config/zsh/aliases.local.zsh.example ~/.config/zsh/aliases.local.zsh
```

The example carries everything that used to be in the deployed `aliases.zsh`:
the Laravel shortcuts, the workspace `cd` aliases, `typora` / `edge`, the MySQL
and Redis helpers, the four AI-CLI shortcuts, the SketchyBar service aliases and
the three other update paths. Uncomment what you use.

For login-shell blocks that vendor CLIs add to `~/.config/zsh/.zprofile`, use
`~/.config/zsh/private.zprofile` instead. `.zprofile` sources it, and unlike
`.zprofile` itself it is never deployed, so an update of this repo cannot drop it.

### `personal.zsh` is gone

Earlier versions shipped an empty, tracked `personal.zsh` and deployed it, so
anything written into it was replaced on the next update. It is no longer
tracked or deployed. An existing one with content is still sourced, once, with a
note asking you to rename it to `private.zsh`; an empty one can be deleted.

## Quick checks

```bash
zsh -n home/.config/zsh/*.zsh
zsh -n home/.zshenv
bash tests/smoke/shell_layer_smoke.sh
```

## Common workflow keys in shell layer

- `Ctrl + 1..0` etc are workspace keys handled by AeroSpace and Karabiner.
- `CapsLock` actions are handled by Karabiner + Hammerspoon, not by `zsh`.
