# AI-First macOS Dotfiles

**Thirteen tiled workspaces, a CapsLock AI layer, and an installer that prints every package and every file it will touch — before it touches one.**

[![CI](https://github.com/aklmans/ai-first-dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/aklmans/ai-first-dotfiles/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-only-black.svg)

<img src="assets/screenshots/aerospace-tiling-layout.png" alt="Two windows tiled side by side by AeroSpace, with the SketchyBar workspace row across the top of the screen" width="100%">

<sub>One <code>Ctrl</code> chord switched to that workspace, AeroSpace tiled both windows, SketchyBar drew the row on top. No window was dragged, no space was swiped.</sub>

<!-- TODO(author): record assets/demo.gif — ~10s: Ctrl+1..4 through workspaces,
     Alt+H/L to move focus, then CapsLock+Space to open the AI palette.
     Then replace the line below with:
     <img src="assets/demo.gif" alt="Switching workspaces and opening the AI palette" width="100%"> -->

## Try it without installing anything

```bash
git clone https://github.com/aklmans/ai-first-dotfiles.git
cd ai-first-dotfiles
./bootstrap/setup.sh all --dry-run
```

`--dry-run` executes nothing and needs no Homebrew. It prints every command and
every path under your `$HOME` the real run would write, one line each. Read that
list. If you do not like it, delete the clone and you are exactly where you
started.

When you are ready:

```bash
./bootstrap/setup.sh all        # or: shell / desktop / ai — see below
```

---

## What it costs

Most dotfiles repos tell you what they give you. Here is what they take.

| Profile | Homebrew packages | Writes to `$HOME` | macOS permissions | Restart | Takes over | Reversible |
|---|---|---|---|---|---|---|
| `ai` | 0 | 1 path (`~/.config/ai-router`, ~80 files) | none | no | nothing | yes |
| `shell` | 25 | 6 paths (~24 files) | none | new shell | `~/.zshenv` — points `ZDOTDIR` at this repo | yes |
| `desktop` | 13 | 6 paths (~58 files) | Accessibility, Input Monitoring, a Karabiner driver extension | yes, for the driver | `Ctrl+1..0`, `Ctrl+[ ] \`, `Alt`+letters; `CapsLock` once you enable the rule | yes |
| `all` | 55 | 10 paths (~193 files) | same as `desktop` | yes, for the driver | same as `desktop`, plus the `PATH` GUI apps inherit | yes |

Package counts are the unique formulae and casks each profile installs, read out
of [`bootstrap/brew.sh`](bootstrap/brew.sh) and the `brew_install` lines in
`bootstrap/install/`. File counts come from the `deploy_repo_path` calls in the
same scripts — `./bootstrap/setup.sh <profile> --dry-run` prints the exact list
for your machine, and that output is the authority, not this table.

**`all` is not everything.** It deliberately leaves out two profiles:

- **`shell`** repoints `~/.zshenv` at this repo. That is the most invasive thing
  in here and the hardest to undo by hand, so it is opt-in:
  `./bootstrap/setup.sh shell`.
- **`extras`** is BetterTouchTool (free for 45 days, paid after) and Warp
  (closed source, wants an account). Nothing else here depends on either:
  `./bootstrap/setup.sh extras`.

Everything is copied, never symlinked. A redeploy skips unchanged files, keeps
files you edited yourself, refuses to write through a symlink another dotfiles
manager owns, and backs up anything it does replace — with a ledger that
[`bootstrap/uninstall.sh`](bootstrap/uninstall.sh) can replay.

---

## What you get

| Module | Tools | What it actually does |
|---|---|---|
| Workspaces | [AeroSpace](https://github.com/nikitabobko/AeroSpace) | 13 tiled workspaces, one `Ctrl` chord each, apps land on the same workspace every time |
| Desktop UI | [SketchyBar](https://github.com/FelixKratz/SketchyBar), [JankyBorders](https://github.com/FelixKratz/JankyBorders) | Workspace row with live app icons, a border around the focused window |
| Keyboard layer | [Karabiner-Elements](https://karabiner-elements.pqrs.org) | CapsLock: tap for `Esc`, hold for Hyper, plus arrow/delete chords under the home row |
| Automation | [Hammerspoon](https://www.hammerspoon.org) | Turns those chords into actions: AI palette, agent chooser, screencast window presets |
| AI workflows | `ai-router` | 18 prompts, selection capture, provider fallback, Raycast snippet export — all local files |
| Terminal | [Kaku](https://github.com/tw93/kaku), zsh, [Starship](https://starship.rs), [Yazi](https://yazi-rs.github.io) | Shell config, prompt, terminal file manager |
| Editors / media | IdeaVim, Sublime Text, [mpv](https://mpv.io) | Vim bindings in JetBrains IDEs, open-in-terminal from Sublime, media player config |

> **`ai-router` is on its way out of this repo.** It has grown past "a dotfiles
> module" and is being split into a standalone project, `hotprompt`. Until that
> lands, it lives here and is installed by `./bootstrap/setup.sh ai`.

---

## Prerequisites

- **Apple Silicon Mac.** The AeroSpace, Hammerspoon and SketchyBar layers name
  the `/opt/homebrew` prefix in two dozen places, and Intel Homebrew lives at
  `/usr/local`. On an Intel Mac the install would finish without an error and
  leave nothing wired up, so `setup.sh` refuses before writing anything.
  `--dry-run` still previews on any machine.
- macOS 13 Ventura or later
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools: `xcode-select --install`
- Git (ships with the Command Line Tools)

`setup.sh` checks all four and stops with one readable message rather than
failing halfway through. Set `DOTFILES_SKIP_PREFLIGHT=1` to bypass it.

---

## macOS permissions

Nothing here can grant these for you. Until you do, the app in question runs and
does nothing, which reads exactly like a broken config.

| App | Permission | Where | Without it |
|---|---|---|---|
| **AeroSpace** | Accessibility | Privacy & Security → Accessibility | Windows never move. Nothing tiles. |
| **Karabiner-Elements** | Driver extension + Input Monitoring | Login Items & Extensions → Driver Extensions, then Privacy & Security → Input Monitoring | No CapsLock layer at all. macOS asks you to restart after approving the driver. |
| **Hammerspoon** | Accessibility | Privacy & Security → Accessibility | AI hotkeys do nothing, screencast presets do nothing. |
| **Hammerspoon** | Automation → System Events | Privacy & Security → Automation (prompts on first use) | Prompts render but never pick up your selection. |
| **SketchyBar** | none for the bar itself | — | — |
| **SketchyBar** | Automation → Spotify | prompts the first time you click the media item | The media item does nothing. Everything else on the bar is fine. |
| **BetterTouchTool** *(`extras`)* | Accessibility + Input Monitoring | Privacy & Security | Trackpad gestures do nothing. |
| Any app | Screen Recording | Privacy & Security | Only needed if you bind the screenshot/OCR chords to a capture tool. |

---

## Shortcuts that fight macOS

Read this before deciding the config is broken. These are real collisions, and
macOS wins by default.

**`Ctrl + ←` / `Ctrl + →` collide with "Move left/right a space", which macOS
ships enabled.** Turn them off, or workspace-group cycling will feel random:

> System Settings → Keyboard → Keyboard Shortcuts… → Mission Control →
> uncheck **Move left a space** and **Move right a space**

**`Ctrl + 1..9` collide with "Switch to Desktop N"** in the same panel. They only
fire when you have more than one macOS Desktop, so a single-Space setup usually
never notices — but if you keep several Desktops, uncheck those rows too.

**CapsLock stops being CapsLock.** Karabiner claims the whole key: tap for `Esc`,
hold for Hyper. There is no caps lock any more. If you switch input methods with
it, macOS will fight Karabiner for every tap:

> System Settings → Keyboard → Input Sources → Edit… →
> turn off **Use the Caps Lock key to switch to and from ABC**

**The CapsLock rules ship disabled.** `karabiner.sh` installs them as a
complex-modification asset rather than overwriting your Karabiner profile — that
file is a live keyboard driver's state, and this repo will not replace it behind
your back. Turn the rules on yourself:

> Karabiner-Elements → Complex Modifications → Add rule →
> **CapsLock AI Lite (ai-first-dotfiles)** → Enable All

**`Ctrl + ↑` / `Ctrl + ↓` need BetterTouchTool.** They route Mission Control and
App Exposé through BTT, which lives in the `extras` profile. Without it those two
keys silently do nothing.

---

## Core workflow keys

### Workspaces — AeroSpace

| Keys | Action |
|---|---|
| `Ctrl + 1..0` | Switch to workspace 1–10 |
| `Ctrl + [` / `Ctrl + ]` / `Ctrl + \` | Switch to workspace 11 / 12 / 13 |
| `Ctrl + Shift + <same>` | Move the focused window there and follow it |
| `Ctrl + ←` / `Ctrl + →` | Cycle workspace groups |
| `Alt + H/J/K/L` | Move focus inside the tiled layout |
| `Alt + Shift + H/J/K/L` | Swap the focused window |
| `Alt + Shift + T` | Float / tile the focused window |
| `Alt + Shift + R` | Repair this workspace: default placement, flatten, balance |
| `Option + Shift + Space` | Hide SketchyBar on the main display and reclaim its gap |

### AI layer — CapsLock

| Keys | Action |
|---|---|
| `CapsLock + Space` | AI palette (every prompt, searchable) |
| `CapsLock + A/S/T/E/W/F/X/R/G/D/Y/=` | Render that prompt with your selection, copy to clipboard |
| `CapsLock + Shift + <same letter>` | Send it to a provider and put the answer on the clipboard |
| `CapsLock + C` | Coding agent chooser (Codex, Claude Code, Junie, Gemini, Kimi, …) |
| `CapsLock + H/J/K/L` | Arrow keys, without leaving the home row |
| `CapsLock + N` / `CapsLock + M` | Delete previous word / previous character |

Rendering a prompt is free and local. Calling a provider is always a separate,
deliberate gesture — never the default.

Full map, including window layout, displays, trackpad gestures and screencast
presets: **[docs/shortcuts.md](docs/shortcuts.md)**.

---

## Make it yours

Every module has one file meant for your edits. The deploy engine notices when
you have changed one and stops overwriting it, so these survive updates.

| You want to change | Edit | Then |
|---|---|---|
| Which monitor is `main` / `side` / `stage` | `~/.config/aerospace/displays.conf` | `~/.config/aerospace/render-layout.sh` |
| How many workspaces exist, and where | `~/.config/aerospace/workspaces.conf` | `~/.config/aerospace/render-layout.sh` |
| Which app opens on which workspace | `~/.config/aerospace/app-defaults.sh` | `~/.config/aerospace/render-app-rules.sh` |
| Bar font, height, colors | `~/.config/sketchybar/theme.conf` | `brew services restart sketchybar` |
| Focused-window border color and width | `~/.config/borders/bordersrc` | `brew services restart borders` |
| Machine-local shell vars, API keys, `PATH` | `~/.config/zsh/private.zsh` | new shell |
| Prompt text, and adding your own prompts | `~/.config/ai-router/prompts/` | `~/.config/ai-router/ai-router.sh index` |
| Which agents the chooser offers | `~/.config/ai-router/config.json` | reload Hammerspoon |

One display works out of the box: leave `displays.conf` empty and `main`, `side`
and `stage` all resolve to whatever screen is actually connected.

Run `~/.config/aerospace/doctor.sh` when the desk and the config disagree.

---

## Uninstall

```bash
./bootstrap/uninstall.sh            # prints the plan, changes nothing
./bootstrap/uninstall.sh --apply    # performs it
```

It replays the backup ledger newest-first. A file byte-identical to the copy this
repo shipped is removed; anything you changed is moved aside, never deleted;
symlinks and non-empty directories are never touched. It also stops the
SketchyBar and Borders services and reverts the two system settings the install
changed.

Homebrew packages are left alone on purpose — you may have wanted `ripgrep`
anyway. `brew uninstall` whatever you don't.

---

## Security & privacy

- **No API keys, anywhere.** The AI layer stores no credentials: every provider
  shells out to a CLI you have already signed into (`codex`, `claude`, `gemini`,
  `ollama`, …), and `ai-router` redacts key-shaped strings out of its own error
  logs before writing them.
- Machine-local secrets belong in `~/.config/zsh/private.zsh`, which is not
  tracked. `home/.config/zsh/private.zsh.example` shows the shape.
- The tracked Karabiner config carries no `vendor_id`/`product_id` pairs — those
  identify the exact keyboards a person owns.
- App Store manifests ship empty, and `bootstrap/app-store.sh` prints what it
  would install and asks first.
- `examples/macos-defaults/` holds `defaults write` tweaks from the author's
  machine. **No profile ever runs them.** Read them and run them yourself if you
  want them.
- `tests/smoke/privacy_scan_smoke.sh` enforces all of the above on every push,
  and fails on any real `/Users/<name>` path, token-shaped string or private key
  header in tracked files.

Details: [docs/privacy.md](docs/privacy.md).

---

## Repo layout

```
.
├── home/           # Source of truth — copied into your home directory
├── bootstrap/      # setup.sh, uninstall.sh, brew.sh, per-module installers
├── manifests/      # Package lists for optional App Store tooling
├── examples/       # Reference material no profile ever runs
├── tests/smoke/    # 12 suites: deploy engine, orchestration, privacy, module behavior
└── docs/           # Documentation
```

---

## Docs

- **[Getting started](docs/getting-started.md)** — install paths, profiles, what runs when
- **[Troubleshooting](docs/troubleshooting.md)** — it installed but nothing happens
- **[Shortcut reference](docs/shortcuts.md)** — every binding in one page
- **[Privacy & public safety](docs/privacy.md)** — what is excluded and why
- **[All documentation](docs/README.md)** — per-module notes, screenshots, architecture

## Contributing

Issues and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for how to run
the test suite and what kinds of change fit here. Changes are logged in
[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
