# AI-First macOS Dotfiles

**A composable macOS workspace system: take two modules or the whole desk, see
every cost and permission first, and keep your own preferences.**

[![CI](https://github.com/aklmans/ai-first-dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/aklmans/ai-first-dotfiles/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-only-black.svg)

<img src="assets/screenshots/aerospace-tiling-layout.png" alt="Two windows tiled side by side by AeroSpace, with the SketchyBar workspace row across the top of the screen" width="100%">

<sub>One <code>Ctrl</code> chord switched to that workspace, AeroSpace tiled both windows, SketchyBar drew the row on top. No window was dragged, no space was swiped.</sub>

This repository is the author's complete setup, but the product is not “become
the author.” Workspace management, the bar, CapsLock, automation, AI, shell,
terminals and paid extras are independent choices. The complete 13-workspace
desk remains available as a reference preset.

## See your choices without installing anything

```bash
git clone https://github.com/aklmans/ai-first-dotfiles.git
cd ai-first-dotfiles
./bootstrap/setup.sh list
./bootstrap/setup.sh minimal --dry-run
./bootstrap/setup.sh recommend
```

`list` shows each independent outcome, its cost, permissions and dependencies.
`--dry-run` executes nothing and needs no Homebrew; it prints the exact taps,
formulae, casks, commands and paths the real run would use.

`recommend` is also read-only by default. It detects connected displays and a
small catalog of locally installed applications, asks about common scenes on a
real terminal, then recommends 4, 6, 8 or 10 semantic workspaces. Detection is
local, is not retained, and never implies buying or installing an application.
Only `recommend --apply` writes the reviewed data and installs its free modules.

When you are ready:

```bash
./bootstrap/setup.sh minimal                 # workspace + bar
./bootstrap/setup.sh capslock automation ai  # compose only what you want
```

## Choose an outcome, not someone else's taste

Presets are shortcuts, not product tiers. You can start with one and add any
module, or ignore presets entirely.

| Preset | Includes | It deliberately leaves out |
|---|---|---|
| `minimal` | AeroSpace + SketchyBar, portable dialog/layout rules, and exact user routes | shipped app placement, CapsLock takeover, AI, notifications, recording, shell, accounts and paid apps |
| `developer` | `minimal` + CapsLock + Hammerspoon + local AI workflows; eight task workspaces with no shipped app placement | notifications, recording, shell, paid and closed-source apps |
| `author-full` | the maintained 13-workspace desk and every integration | nothing; explicitly includes BetterTouchTool (paid after trial), Warp (closed source/account) and shell takeover |

Workspaces describe tasks, not application brands. Physical displays only
decide where those task roles appear: one display carries every role, two split
main/support work, and a third can become a stage. Applications follow the
current workspace unless the user selects a routing pack or creates an exact
`follow`, `prefer` or `fixed` rule.

Modules are the stable public interface:

| Outcome | Module | Dependency / trade-off |
|---|---|---|
| predictable tiled workspaces | `workspace` | AeroSpace; Accessibility |
| workspace/app status | `bar` | adds `workspace`; no special permission |
| focused-window border | `borders` | adds `workspace`; service stays stopped by default |
| CapsLock tap Esc / hold Hyper | `capslock` | Karabiner driver + Input Monitoring; rule remains disabled until you enable it |
| window and chooser automation | `automation` | adds `workspace`; Hammerspoon Accessibility/Automation |
| local prompts/provider adapters | `ai` | no account required by the router; providers are your choice |
| four-app attention badge | `notifications` | adds `bar`; SketchyBar Full Disk Access; choose any subset of Warp, Codex, IntelliJ IDEA, GoLand |
| screencast window presets | `recording` | adds `automation`; capture permission is separate |
| trackpad workspace gestures | `gestures` | BetterTouchTool, paid after trial |
| terminal integrations | `terminal` / `warp` | Kaku is free/open; Warp is separate, closed/account-based opt-in |
| shell, editors and media | `shell`, `sublime`, `media` | `shell` changes `ZDOTDIR`; the others stand alone |

Run `./bootstrap/setup.sh list` for the authoritative catalog. See
[Choice architecture](docs/choice-architecture.md) for composition examples,
profile settings and the boundary between a preference and an implementation.

Everything is copied, never symlinked. A redeploy keeps local edits, refuses to
write through another manager's symlink, and backs up replacements in a ledger
that [`bootstrap/uninstall.sh`](bootstrap/uninstall.sh) can replay.

---

## What you get

| Module | Tools | What it actually does |
|---|---|---|
| Workspaces | [AeroSpace](https://github.com/nikitabobko/AeroSpace) | 6 neutral workspaces in `minimal`, 8 task workspaces in `developer`, or the author's 13-workspace/multi-display reference map |
| Desktop UI | [SketchyBar](https://github.com/FelixKratz/SketchyBar), [JankyBorders](https://github.com/FelixKratz/JankyBorders) | Workspace row with live app icons, a border around the focused window |
| Keyboard layer | [Karabiner-Elements](https://karabiner-elements.pqrs.org) | CapsLock: tap for `Esc`, hold for Hyper, plus arrow/delete chords under the home row |
| Automation | [Hammerspoon](https://www.hammerspoon.org) | Turns those chords into actions: AI palette, agent chooser, screencast window presets |
| AI workflows | `ai-router` | 18 prompts, selection capture, provider fallback, Raycast snippet export — all local files |
| Terminal | Terminal.app, [Kaku](https://github.com/tw93/kaku), Warp, zsh, [Starship](https://starship.rs), [Yazi](https://yazi-rs.github.io) | choose the terminal separately from the workflow; Warp is never implied by AI |
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
| **SketchyBar** *(`notifications`)* | Full Disk Access | Privacy & Security → Full Disk Access | The four-app attention badge cannot read macOS notification metadata. |
| **BetterTouchTool** *(`gestures`)* | Accessibility + Input Monitoring | Privacy & Security | Trackpad gestures do nothing. |
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
App Exposé through BTT, which is the explicit `gestures` module. Without it those
two keys silently do nothing.

---

## Core workflow keys

### Workspaces — AeroSpace

| Keys | Action |
|---|---|
| `Ctrl + 1..6` | Switch to workspace 1–6 (all presets) |
| `Ctrl + 7..0` | Switch to workspace 7–10 when configured (`developer`/`author-full`) |
| `Ctrl + [` / `Ctrl + ]` / `Ctrl + \` | Switch to workspace 11 / 12 / 13 when configured (`author-full`) |
| `Ctrl + Shift + <same>` | Move the focused window there and follow it |
| `Ctrl + ←` / `Ctrl + →` | Cycle workspace groups |
| `Alt + H/J/K/L` | Move focus inside the tiled layout |
| `Alt + Shift + H/J/K/L` | Swap the focused window |
| `Alt + Shift + T` | Float / tile the focused window |
| `Alt + Shift + R` | Repair this workspace: default placement, flatten, balance |
| `Option + Shift + B` | Bind the focused app to the current workspace |
| `Option + Shift + U` | Unpin the focused app; new windows stay where opened |
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

Common choices have designated data files. The deploy engine notices when you
have changed one and stops overwriting it, so these survive updates.

| You want to change | Edit | Then |
|---|---|---|
| Which capabilities are visible or active | `~/.config/ai-first/profile.conf` | reload the affected app |
| Which monitor is `main` / `side` / `stage` | profile values or `~/.config/aerospace/displays.conf` | `~/.config/aerospace/render-layout.sh` |
| How many workspaces exist, and where | profile values or `~/.config/aerospace/workspaces.conf` | `~/.config/aerospace/render-layout.sh` |
| Which semantic role points to each workspace | `AEROSPACE_WORKSPACE_ROLE_MAP` in `profile.conf` or `workspaces.conf` | `~/.config/aerospace/plan.sh --check` |
| Get a machine-aware first layout | connected displays, installed apps and a short scene questionnaire | `./bootstrap/setup.sh recommend` |
| Say the workspace count feels wrong | explicit `fewer`, `keep` or `more` feedback | `./bootstrap/setup.sh tune` |
| Which shipped app routing pack is active | `AI_FIRST_ROUTING_PACK` in `profile.conf` | `~/.config/aerospace/render-app-rules.sh` |
| Bind the focused app to this workspace | any app window | `~/.config/aerospace/app-route.sh bind-here` |
| Let the focused app follow the current workspace | any app window | `~/.config/aerospace/app-route.sh follow` |
| Prefer a task role for the focused app | any app window | `~/.config/aerospace/app-route.sh prefer <role>` |
| Propose routes from a desktop you arranged | current AeroSpace windows, read once | `~/.config/aerospace/app-route.sh capture-current` |
| Batch-edit app workspace/layout choices | `~/.config/aerospace/app-routes.conf` | `~/.config/aerospace/render-app-rules.sh` |
| Which supported notification apps are shown | `AI_FIRST_NOTIFICATION_APPS` in `profile.conf` | `brew services restart sketchybar` |
| Which terminal receives AI prompts | `AI_FIRST_TERMINAL_APP` in `profile.conf` | reload Hammerspoon |
| Bar font, height, colors | `~/.config/sketchybar/theme.conf` | `brew services restart sketchybar` |
| Focused-window border color and width | `~/.config/borders/bordersrc` | `brew services restart borders` |
| Machine-local shell vars, API keys, `PATH` | `~/.config/zsh/private.zsh` | new shell |
| Prompt text, and adding your own prompts | `~/.config/ai-router/prompts/` | `~/.config/ai-router/ai-router.sh index` |
| Which agents the chooser offers | `~/.config/ai-router/config.json` | reload Hammerspoon |

One display works out of the box: leave `displays.conf` empty and `main`, `side`
and `stage` all resolve to whatever screen is actually connected.

Run `~/.config/aerospace/doctor.sh` when the desk and the config disagree.
Run `~/.config/aerospace/plan.sh` to see the resolved displays, roles, routing
pack and exact app targets before applying anything.
Run `~/.config/aerospace/app-route.sh capture-current` after arranging windows
the way you like. It previews `follow`/`prefer` suggestions from that one
snapshot; `--apply` saves them in a generated layer below handwritten routes.
No background activity logging is enabled.
Run `./bootstrap/setup.sh doctor <module|preset>` for a read-only install and
permission checklist.

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
├── bootstrap/      # catalog, setup/doctor/uninstall, presets, module installers
├── manifests/      # Package lists for optional App Store tooling
├── examples/       # Reference material no profile ever runs
├── tests/smoke/    # regression suites: deploy, choices, orchestration, privacy, behavior
└── docs/           # Documentation
```

---

## Docs

- **[Getting started](docs/getting-started.md)** — install paths, profiles, what runs when
- **[Choice architecture](docs/choice-architecture.md)** — modules, presets and safe preference points
- **[Product quality scorecard](docs/product-quality.md)** — the 8.5 release gate and evidence
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
