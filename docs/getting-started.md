# Getting Started

Start with the smallest outcome you want. This project does not require its
shell, terminal, AI tools, paid apps or the author's display layout.

Requires an **Apple Silicon** Mac on macOS 13 or later. A real install also
needs Homebrew and the Xcode Command Line Tools; previews do not.

## 1. Inspect the choices

```bash
git clone https://github.com/aklmans/ai-first-dotfiles.git
cd ai-first-dotfiles
./bootstrap/setup.sh list
```

The catalog describes outcomes rather than internal folders. Every module names
its cost, macOS permissions and dependencies. Presets are only shortcuts:

| Preset | Good starting point for | Modules |
|---|---|---|
| `minimal` | a free, low-commitment tiled desktop | `workspace bar` |
| `developer` | keyboard-driven development and local AI prompts | `workspace bar capslock automation ai` |
| `author-full` | reproducing the maintained reference desk | all modules, including paid/closed choices |

You can ignore presets and compose modules:

```bash
./bootstrap/setup.sh workspace capslock
./bootstrap/setup.sh workspace bar automation ai terminal
./bootstrap/setup.sh minimal ai
```

Dependencies are added once. For example, `bar` adds `workspace`, and
`notifications` adds `bar` and `workspace`.

If workspace counts and routing policies are unfamiliar, let the local advisor
build a recommendation instead of choosing a preset first:

```bash
./bootstrap/setup.sh recommend
```

It detects connected displays and recognized installed apps, then asks about
common scenes when run in a real terminal. The preview recommends 4, 6, 8 or 10
task workspaces and shows their `main`/`side`/`stage` distribution. It stores no
detection result and writes nothing until the plan is re-run with `--apply`.

## 2. Preview the exact plan

```bash
./bootstrap/setup.sh minimal --dry-run
```

The preview executes and writes nothing. It names exact Homebrew taps,
formulae/casks, module commands, target paths, costs and permissions. Use the
same command with your intended modules; that output is more authoritative than
a package count copied into documentation.

Paid and closed-source choices appear only when explicitly selected:

```bash
./bootstrap/setup.sh gestures --dry-run   # BetterTouchTool, paid after trial
./bootstrap/setup.sh warp --dry-run       # Warp, closed source/account
```

## 3. Install

```bash
./bootstrap/setup.sh minimal
```

Or apply the reviewed machine-aware plan:

```bash
./bootstrap/setup.sh recommend --apply
```

The advisor installs only its free recommended modules. It does not infer
notifications/Full Disk Access, BetterTouchTool or Warp. Use
`--apply --config-only` when the underlying tools already exist and only the
generated profile and route advice should change.

Useful flags:

| Flag | Effect |
|---|---|
| `--dry-run` | exact plan; execute nothing and write nothing |
| `--no-brew` | skip Homebrew, keep applicable non-brew setup |
| `--deploy-only` | copy config only; install/start nothing and change no macOS setting |
| `--install-only` | install packages/external dependencies; write nothing to `$HOME` |

`DOTFILES_FORCE=1` replaces protected local changes or symlinked targets only
after backing them up. It is not needed for normal updates.

Everything deploys as copies, never symlinks. One failed module is reported at
the end without preventing independent modules from being attempted. Re-running
the same command is expected and safe.

## 4. Grant only the permissions for your modules

```bash
./bootstrap/setup.sh doctor minimal
```

The doctor is read-only. It checks installed outcomes and separates missing
files/commands from manual permissions or cost notes.

- `workspace`: AeroSpace Accessibility
- `capslock`: Karabiner Driver Extension and Input Monitoring
- `automation`: Hammerspoon Accessibility and Automation
- `notifications`: Full Disk Access for SketchyBar
- `gestures`: BetterTouchTool Accessibility and Input Monitoring

The Karabiner CapsLock rule is deployed disabled. Enable it under
Karabiner-Elements → Complex Modifications only if you want CapsLock tap Esc /
hold Hyper.

## 5. Make the result yours

Named presets copy a data-only file to `~/.config/ai-first/profile.conf`.
Changing it does not fork implementation code. It controls feature flags, bar
item groups, supported notification apps, terminal preference, workspace groups,
semantic workspace roles, routing pack and optional display names.

Other safe preference points:

- `~/.config/aerospace/app-routes.conf` — exact app target/policy/layout overrides
- `~/.config/aerospace/app-route.sh bind-here|follow|prefer` — capture the focused app
  without finding its bundle id; Finder and Preview default to `follow`
- `~/.config/aerospace/app-route.sh capture-current` — inspect the desktop once
  and preview routes without enabling background tracking
- `~/.config/aerospace/displays.conf` and `workspaces.conf` — desk topology
- `~/.config/aerospace/plan.sh` — read-only resolved displays, workspace roles,
  routing pack, targets and validation
- `~/.config/sketchybar/theme.conf` — bar fonts, geometry and color roles
- `~/.config/zsh/private.zsh` — machine-local shell values and secrets
- `~/.config/ai-router/config.json` and `prompts/` — provider and prompt choices

After using an advisor profile for a while, explicit feedback changes one
dimension at a time:

```bash
./bootstrap/setup.sh tune
./bootstrap/setup.sh tune --workspace-feedback fewer --apply
~/.config/aerospace/app-route.sh capture-current --apply
```

Handwritten routes remain above captured routes, captured routes remain above
install-time advice, and all local layers remain above an optional shipped
routing pack.

The deploy engine preserves local changes. See
[Choice architecture](choice-architecture.md) for every setting and example.

## Compatibility commands

Older automation can still use `all`, `desktop`, `extras`, `packages`,
`packages-all`, `shell`, `ai`, `media`, `app-store` and `deploy`. `all` is no
longer the recommended entry point. It preserves its previous behavior and does
not mean “every possible module.”

Each `bootstrap/install/*.sh` script also remains independently runnable with
the common flags.

## Undoing it

```bash
./bootstrap/uninstall.sh            # plan only
./bootstrap/uninstall.sh --apply    # restore/remove deployed files safely
```

The uninstaller replays the backup ledger. It removes only unchanged repository
copies, moves edited files aside, never follows symlinks, and leaves Homebrew
packages alone because another workflow may use them.

## Next

- [Choice architecture](choice-architecture.md)
- [Troubleshooting](troubleshooting.md)
- [Shortcut reference](shortcuts.md)
- [Product quality scorecard](product-quality.md)
