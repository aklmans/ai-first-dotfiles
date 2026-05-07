# AI-First macOS Dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A practical macOS dotfiles setup for keyboard-driven workspaces, a compact desktop UI, terminal tools, and local AI prompt/agent workflows.

Designed for developers who want fast keyboard workflows, predictable multi-display spaces, and AI actions that stay local, inspectable, and easy to customize.

---

## Table of Contents

- [Preview](#preview)
- [What this includes](#what-this-includes)
- [Prerequisites](#prerequisites)
- [Repo structure](#repo-structure)
- [Installation](#installation)
- [macOS permissions](#macos-permissions)
- [Core workflow keys](#core-workflow-keys)
- [Docs](#docs)
- [Notes for public use](#notes-for-public-use)
- [License](#license)

---

## Preview

### Desktop workspace

<img src="assets/screenshots/desktop-overview.png" alt="Desktop overview with SketchyBar and AeroSpace workspaces" width="100%">

### CapsLock AI chooser

<img src="assets/screenshots/capslock-chooser.png" alt="CapsLock AI chooser" width="100%">

→ More screenshots: [docs/screenshots.md](docs/screenshots.md)

---

## What this includes

| Module | Tools | Purpose |
|---|---|---|
| Workspace automation | `AeroSpace`, `BetterTouchTool` | Tiling layouts, display-aware workspace keys, trackpad gestures |
| Desktop status UI | `SketchyBar`, `Borders` | Workspace indicators, app icons, focused-window feedback |
| CapsLock AI layer | `Karabiner`, `Hammerspoon` | Hotkeys for prompts, snippets, app launchers, agent entry points |
| AI Workflow Router | `ai-router` | Local prompts, snippets, provider scripts, chooser, snippet exports |
| Terminal workflow | `Kaku`, `Warp`\*, `zsh`, `Starship`, `Yazi`, GUI PATH helper | Shell ergonomics, file manager, terminal stack, Homebrew tools for GUI-launched apps |
| Editor / media | `IdeaVim`, Sublime Text Terminal integration, `mpv` | Vim bindings in JetBrains IDEs, Warp launch from Sublime, media player config |

\* optional

---

## Prerequisites

- macOS 13 Ventura or later
- [Homebrew](https://brew.sh) installed
- Xcode Command Line Tools: `xcode-select --install`
- Git: bundled with Xcode CLT or via `brew install git`

---

## Repo structure

```
.
├── home/           # Source of truth — deployed to your home directory
├── bootstrap/      # Installers and bootstrap scripts
│   └── install/    # Per-module install scripts
├── manifests/      # Package lists for optional App Store tooling
├── templates/      # Credential/config templates (no secrets)
├── tests/smoke/    # Repo-wide validation and privacy checks
└── docs/           # Public documentation
```

---

## Installation

Run the setup entrypoint from the repo root:

```bash
cd /path/to/ai-first-dotfile
./bootstrap/setup.sh all
```

Useful variants:

```bash
./bootstrap/setup.sh deploy          # deploy tracked config only
./bootstrap/setup.sh all --no-brew   # skip Homebrew, keep non-brew setup steps
./bootstrap/setup.sh gui-path        # make Homebrew tools visible to GUI-launched apps
./bootstrap/setup.sh desktop         # desktop/window-management layer only
./bootstrap/setup.sh shell           # shell, terminal, and file-manager layer only
./bootstrap/setup.sh sublime         # Sublime Text Terminal package integration only
./bootstrap/setup.sh ai              # AI Workflow Router only
./bootstrap/setup.sh all --dry-run   # preview commands
```

The setup script keeps config deployment copy-based, not symlink-based. Re-running it is intended to be safe: unchanged targets are skipped and backups are created only when a target differs.

### Manual module install

Each module script also supports:

```bash
--deploy-only    # deploy config, skip Homebrew
--install-only   # install packages/external dependencies, skip config deploy
--no-brew        # skip Homebrew but keep non-brew setup steps
```

Manual order, if you do not want to use `setup.sh`:

#### 1. Core bootstrap

```bash
./bootstrap/brew.sh base desktop fonts
./bootstrap/install/gui-path.sh
./bootstrap/app-store.sh
```

#### 2. Shell and terminal

```bash
./bootstrap/install/zsh.sh
./bootstrap/install/starship.sh
./bootstrap/install/kaku.sh
./bootstrap/install/yazi.sh
./bootstrap/install/warp.sh       # optional
./bootstrap/install/ideavim.sh    # optional
./bootstrap/install/sublime.sh     # optional
```

#### 3. Desktop and workspace

```bash
./bootstrap/install/karabiner.sh
./bootstrap/install/aerospace.sh
./bootstrap/install/sketchybar.sh
./bootstrap/install/borders.sh
./bootstrap/install/bettertouchtool.sh  # optional
./bootstrap/install/hammerspoon.sh
```

#### 4. AI workflow

```bash
./bootstrap/install/ai-router.sh
```

#### 5. Media and optional assistants

```bash
./bootstrap/install/mpv.sh        # optional
./bootstrap/install/gbrain.sh     # optional (local-only template-based setup)
```

#### 6. Validate

```bash
bash tests/smoke/repository_structure_smoke.sh
bash tests/smoke/install_script_syntax_smoke.sh
bash tests/smoke/ai_router_exports_smoke.sh
```

> Optional modules can be installed any time. Re-run only the scripts you need.

See [docs/getting-started.md](docs/getting-started.md) for rationale and path notes.

---

## macOS permissions

Grant the following permissions when prompted (System Settings → Privacy & Security):

| Permission | Required by |
|---|---|
| Accessibility | `Karabiner`, `Hammerspoon`, `BetterTouchTool` |
| Input Monitoring | `Hammerspoon` (selection/clipboard workflows) |
| Automation | `Hammerspoon` (app launch, command dispatch) |
| Screen Recording | Only if you use screenshot/OCR capture actions |

---

## Core workflow keys

### AeroSpace — workspace switching

| Keys | Action |
|---|---|
| `Ctrl + 1..0` | Switch workspace 1–10 |
| `Ctrl + [` / `Ctrl + ]` | Switch workspace 11 / 12 |
| `Ctrl + \` | Switch workspace 13 |
| `Ctrl + Shift + 1..0` | Move focused window to workspace |
| `Ctrl + Shift + \` | Move focused window to workspace 13 |
| `Ctrl + Left/Right` | Cycle workspace groups |
| `Ctrl + Up/Down` | Mission Control / App Exposé |
| `Alt + H/J/K/L` | Move focus in tiled layout |
| `Option + Shift + Space` | Toggle SketchyBar and matching AeroSpace top gap |
| `Ctrl + Alt + Cmd + M` | Enter Recording Mode on workspace 13 |
| `Ctrl + Alt + Cmd + Shift + M` | Exit Recording Mode |

### AI hotkeys (CapsLock layer)

| Keys | Action |
|---|---|
| `CapsLock + Space` | AI workflow palette / chooser |
| `CapsLock + C` | Coding Agent chooser |
| `CapsLock + A/S/T/E/W/F/X/R/G/D/Y/=` | Render prompt types via AI Router |
| `CapsLock + Ctrl + W/I/G/X/H/C/L` | Direct app / agent launch |

### BetterTouchTool trackpad gestures

| Gesture | Action |
|---|---|
| 3/4-finger left/right | Previous / next workspace |
| 3/4-finger up | Mission Control |
| 3/4-finger down | App Exposé |

Full shortcut reference: [docs/shortcuts.md](docs/shortcuts.md)

---

## Docs

**Setup**
- [Getting started](docs/getting-started.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Privacy policy](docs/privacy.md)
- [Shortcut reference](docs/shortcuts.md)
- [Screenshots](docs/screenshots.md)
- [Workflow overview](docs/tools/current-workflow/README.md)

**Tools**
- [AeroSpace](docs/tools/aerospace/README.md)
- [SketchyBar + Borders](docs/tools/sketchybar/README.md)
- [Karabiner](docs/tools/karabiner/README.md)
- [Hammerspoon](docs/tools/hammerspoon/README.md)
- [AI Workflow Router](docs/tools/ai-router/README.md)
- [GUI PATH helper](docs/tools/gui-path/README.md)
- [Zsh + Starship](docs/tools/zsh-starship/README.md)
- [Terminal (Kaku / Warp)](docs/tools/terminal/README.md)
- [Sublime Text](docs/tools/sublime/README.md)
- [Yazi](docs/tools/yazi/README.md)
- [BetterTouchTool](docs/tools/bettertouchtool/README.md)
- [IdeaVim](docs/tools/ideavim/README.md)
- [mpv](docs/tools/mpv/README.md)

---

## Notes for public use

- This is a clean public snapshot rebuilt from a private configuration history.
- Private runtime artifacts, history, and secrets are excluded via `.gitignore` and the public safety policy.
- AI provider credentials are template-only placeholders — no real keys are tracked:
  - `templates/gbrain/.env.local.example`
  - `templates/gbrain/codex-config.example.toml`
- Legacy modules intentionally dropped: `skhd`, `yabai`, `wezterm`, `oh-my-posh`.

---

## License

MIT — see [LICENSE](LICENSE).
