# Terminal and CLI Tooling

This module covers the shell-first terminal stack: the `zsh` base environment,
`Starship`, `Kaku` and `Yazi` — plus `Warp`, which is installed separately.

> **Which profile installs what.** `zsh`, `Starship`, `Kaku` and `Yazi` are the
> `shell` profile, which is opt-in because it repoints `~/.zshenv` at this repo:
> `./bootstrap/setup.sh shell`. **Warp is not in it.** Warp is closed source and
> wants an account, so it lives in `extras` alongside BetterTouchTool:
> `./bootstrap/setup.sh extras`. Neither profile is part of
> `./bootstrap/setup.sh all`.

![Kaku and Warp terminal workflow](../../../assets/screenshots/kaku-warp-terminal.png)

## Installed files

- `home/.config/zsh/*` and `home/.zshenv`
- `home/.config/starship.toml`
- `home/.config/kaku/kaku.lua`
- `home/.config/kaku/assistant.toml`
- `home/.warp/keybindings.yaml`
- `home/.config/yazi/`
- `bootstrap/install/zsh.sh`
- `bootstrap/install/starship.sh`
- `bootstrap/install/kaku.sh`
- `bootstrap/install/warp.sh`
- `bootstrap/install/yazi.sh`

## Install sequence

```bash
./bootstrap/setup.sh shell    # zsh, Starship, Kaku, Yazi, IdeaVim
./bootstrap/setup.sh extras   # Warp (and BetterTouchTool)
```

Or one module at a time:

```bash
./bootstrap/install/zsh.sh
./bootstrap/install/starship.sh
./bootstrap/install/kaku.sh
./bootstrap/install/yazi.sh
./bootstrap/install/warp.sh
```

## Kaku

`Kaku` is configured in:

- `home/.config/kaku/kaku.lua`
- `home/.config/kaku/assistant.toml`

`bootstrap/install/kaku.sh` installs the Tap formula and deploys the two config files.

## Warp

`home/.warp/keybindings.yaml` is the shared keybinding config.
`bootstrap/install/warp.sh` installs Warp and the Nerd Font used by this setup.

## Yazi

`home/.config/yazi/` contains:

- `yazi.toml`, `keymap.toml`, `init.lua`, `package.toml`
- preview / browse plugins declared by `init.lua`

`bootstrap/install/yazi.sh` installs CLI dependencies and optional extension packages.

## Usage notes

- Shell config entrypoint is `home/.zshenv` + `home/.config/zsh/.zshrc`.
- `private` machine settings can be added in `home/.config/zsh/private.zsh` (not tracked).
- `Homebrew`, `starship`, and `yazi` are required by most installers.

## Related keys

- Core shell and shell tool keys are in `home/.config/zsh/aliases.zsh`.
- `Starship` prompt is controlled by `home/.config/starship.toml`.
- CapsLock AI workflow hotkeys are defined in the Karabiner/Hammerspoon layers, not in these files.
