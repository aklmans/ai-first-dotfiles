# Documentation

Start here if the [README](../README.md) sent you looking for detail.

## Setup and operation

| Page | Read it when |
|---|---|
| [Getting started](getting-started.md) | You are deciding what to install and in what order |
| [Choice architecture](choice-architecture.md) | You want modules, presets and safe preference points |
| [Product quality scorecard](product-quality.md) | You are evaluating public readiness with an 8.5 gate |
| [Release checklist](release-checklist.md) | You are preparing a version or public launch |
| [Troubleshooting](troubleshooting.md) | It installed and nothing happens |
| [Shortcut reference](shortcuts.md) | You want every binding in one page |
| [Privacy and public safety](privacy.md) | You want to know what is excluded from this repo and why |
| [Screenshots](screenshots.md) | You want to see it before you run it |
| [Workflow overview](tools/current-workflow/README.md) | You want the architecture: which module owns what |

## Per-module notes

These document one module each: what it deploys, what you can change, and the
commands worth knowing. None of them are required reading to install.

**Desktop**

- [AeroSpace](tools/aerospace/README.md) — tiling, workspaces, displays, the two config files that own your desk
- [SketchyBar + Borders](tools/sketchybar/README.md) — the bar, its theme file, the workspace items
- [Karabiner](tools/karabiner/README.md) — the CapsLock layer and why it ships disabled
- [Hammerspoon](tools/hammerspoon/README.md) — hotkeys, choosers, screencast presets
- [BetterTouchTool](tools/bettertouchtool/README.md) — trackpad gestures (`gestures` module)

**AI**

- [AI Workflow Router](tools/ai-router/README.md) — prompts, providers, snippet exports

**Shell and terminal**

- [Zsh + Starship](tools/zsh-starship/README.md) — the shell layer, and what taking over `~/.zshenv` means
- [Terminal stack](tools/terminal/README.md) — Kaku, Warp, and how they relate
- [Yazi](tools/yazi/README.md) — terminal file manager
- [GUI PATH helper](tools/gui-path/README.md) — why Sublime cannot find `node` and how this fixes it

**Editors and media**

- [IdeaVim](tools/ideavim/README.md) — Vim bindings in JetBrains IDEs
- [Sublime Text](tools/sublime/README.md) — the three small integrations this repo manages
- [mpv](tools/mpv/README.md) — player config

## Contributing

- [CONTRIBUTING.md](../CONTRIBUTING.md) — how to run the tests, what a good PR looks like
- [CHANGELOG.md](../CHANGELOG.md) — what changed and when
