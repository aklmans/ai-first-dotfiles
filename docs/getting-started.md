# Getting Started

The shortest practical path to bootstrap this setup on a Mac, and what each step
actually does.

Requires an **Apple Silicon** Mac on macOS 13 or later, with Homebrew and the
Xcode Command Line Tools. `setup.sh` checks all of that before it writes
anything; `--dry-run` works on any machine.

## Preview first

```bash
git clone https://github.com/aklmans/ai-first-dotfiles.git
cd ai-first-dotfiles
./bootstrap/setup.sh all --dry-run
```

`--dry-run` executes nothing. It prints every command the run would issue and,
under each one, every path in your `$HOME` it would write, marked `new` or
`exists`. That output is the authoritative answer to "what will this do to my
machine" — more current than any table in these docs.

## Profiles

```bash
./bootstrap/setup.sh all         # the recommended bootstrap
```

`all` is: Homebrew packages (`base desktop fonts`), the GUI PATH helper, the
Sublime Text integrations, the desktop layer, the AI router, and mpv.

Two profiles are deliberately **not** in `all`:

| Profile | Contents | Why it is opt-in |
|---|---|---|
| `shell` | zsh, Starship, Kaku, Yazi, IdeaVim | Installing it repoints `~/.zshenv` at this repo. That is the most invasive change in here and the hardest to undo by hand. Everything else works without it. |
| `extras` | BetterTouchTool, Warp | BetterTouchTool is free for 45 days and paid afterwards; Warp is closed source and wants an account. Nothing else here depends on either. |

The rest:

```bash
./bootstrap/setup.sh shell       # zsh, Starship, Kaku, Yazi, IdeaVim
./bootstrap/setup.sh desktop     # Karabiner, AeroSpace, SketchyBar, Borders, Hammerspoon
./bootstrap/setup.sh extras      # BetterTouchTool, Warp
./bootstrap/setup.sh ai          # AI Workflow Router
./bootstrap/setup.sh media       # mpv
./bootstrap/setup.sh sublime     # Sublime Text Terminal package integration
./bootstrap/setup.sh gui-path    # make Homebrew tools visible to GUI-launched apps
./bootstrap/setup.sh packages    # Homebrew only: base desktop fonts
./bootstrap/setup.sh app-store   # App Store apps from manifests/app-store (ships empty)
./bootstrap/setup.sh deploy      # every tracked config, no package installation
```

`deploy` covers **every** module including `shell` and `extras`, because
deploying installs nothing. If you opted into the shell layer once, a plain
`./bootstrap/setup.sh deploy` keeps its config current.

## Options

| Flag | Effect |
|---|---|
| `--dry-run` | Print what would run, including the `$HOME` paths. Executes nothing. |
| `--no-brew` | Skip Homebrew commands, keep the non-brew setup steps. |
| `--deploy-only` | Deploy config only. Installs nothing, starts nothing, changes no macOS settings. |
| `--install-only` | Install packages and external dependencies only; write nothing to `$HOME`. |

Environment:

- `DOTFILES_SKIP_PREFLIGHT=1` — skip the Apple Silicon / brew / git / Xcode CLT checks.
- `DOTFILES_FORCE=1` — replace symlinked targets and local edits, backing up whatever is replaced.

## What happens if a step fails

Nothing stops. Every step's exit code is captured, the run continues to the end,
and the failures are listed together at the bottom. A partial install is
reported as one, and every step here is safe to run again.

Exit `0` means every step ran, or some paths were deliberately left untouched.
Exit `1` means at least one step failed — read the list at the end.

## Running modules by hand

You do not need `setup.sh`. Each module script stands alone and takes
`--deploy-only`, `--install-only`, `--no-brew`, `--no-deploy` and `--force`.

```bash
# 1. packages
./bootstrap/brew.sh base desktop fonts
./bootstrap/install/gui-path.sh

# 2. desktop
./bootstrap/install/karabiner.sh
./bootstrap/install/aerospace.sh
./bootstrap/install/sketchybar.sh
./bootstrap/install/borders.sh
./bootstrap/install/hammerspoon.sh

# 3. AI workflow
./bootstrap/install/ai-router.sh

# 4. shell and terminal (opt-in — repoints ~/.zshenv)
./bootstrap/install/zsh.sh
./bootstrap/install/starship.sh
./bootstrap/install/kaku.sh
./bootstrap/install/yazi.sh
./bootstrap/install/ideavim.sh

# 5. optional
./bootstrap/install/sublime.sh
./bootstrap/install/mpv.sh
./bootstrap/install/bettertouchtool.sh
./bootstrap/install/warp.sh
```

Install the desktop modules together — Karabiner, AeroSpace, SketchyBar and
Borders share workspace state, and half of them installed looks broken rather
than partial. Everything else can go in any order, any time.

## After installing

Two things the installer cannot do for you:

1. **Grant macOS permissions.** AeroSpace needs Accessibility, Karabiner needs a
   driver extension and Input Monitoring, Hammerspoon needs Accessibility. Until
   you grant them the apps run and do nothing. See the permissions table in the
   [README](../README.md#macos-permissions).
2. **Enable the CapsLock rules.** They are installed as a Karabiner
   complex-modification asset, not written into your profile. Turn them on under
   Karabiner-Elements → Complex Modifications → Add rule.

Then check nothing drifted:

```bash
bash tests/smoke/repository_structure_smoke.sh
bash tests/smoke/install_script_syntax_smoke.sh
bash tests/smoke/ai_router_exports_smoke.sh
```

## Keeping local changes local

The deploy engine already protects files you edit: once a target differs and the
repo copy has not moved since it was deployed, it is kept and reported as
`Kept local change`. Even so, prefer the designated override points rather than
editing tracked files — see **Make it yours** in the [README](../README.md#make-it-yours).

- `~/.config/zsh/private.zsh` for machine-specific shell variables and secrets.
- `~/.config/aerospace/displays.conf` and `workspaces.conf` for your desk.
- `~/.config/sketchybar/theme.conf` for the bar's appearance.

## Undoing it

```bash
./bootstrap/uninstall.sh            # prints the plan, changes nothing
./bootstrap/uninstall.sh --apply
```

## Next

- [Troubleshooting](troubleshooting.md) — it installed and nothing happens
- [Shortcut reference](shortcuts.md) — every binding
- [All documentation](README.md)
