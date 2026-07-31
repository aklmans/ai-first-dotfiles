# AI-First Workflow Overview

This document summarizes the current public architecture of this repository.

## Source of truth

- `home/.aerospace.toml`, `home/.config/aerospace/` -> workspace behavior
- `home/.hammerspoon/` -> local automation flow
- `home/.config/karabiner/` -> keyboard profile and chord mapping
- `home/.config/ai-router/` -> prompts/snippets/providers
- `home/.zshenv`, `home/.config/zsh/` -> shell bootstrap
- `home/.config/sketchybar/`, `home/.config/borders/` -> desktop UI
- `home/.config/kaku/`, `home/.warp/`, `home/.config/yazi/` -> terminal stack
- `home/.config/mpv/` -> player behavior

`bootstrap/install/*.sh` owns deployment for each module.

## Module responsibilities

- **AeroSpace + Karabiner**: workspace switching and keyboard entry layer
- **Hammerspoon + AI Router**: prompt rendering, agent menu flow, and command execution bridge
- **Shell + Terminal stack**: command line ergonomics and file manager workflows
- **Desktop UI stack**: status bar and borders

## AeroSpace essentials

- `Ctrl + 1...0` switch workspace `1..10`
- `Ctrl + [` / `Ctrl + ]` switch workspace `11/12`
- `Ctrl + \` switch workspace `13`
- `Ctrl + Shift + 1...0` move focused window to target workspace
- `Ctrl + Shift + [` / `Ctrl + Shift + ]` move focused window to workspace `11/12`
- `Ctrl + Shift + \` move focused window to workspace `13`
- `Alt + H/J/K/L` move focus in tiled layout
- `Ctrl + Left/Right` cycle workspace groups
- `Ctrl + Up` / `Ctrl + Down` trigger Mission Control / App Exposé through
  `home/.config/aerospace/macos-control.sh`, which drives BetterTouchTool. BTT
  lives in the explicit `gestures` module, so without it these two keys do nothing.

Full shortcut map: [Shortcut Reference](../../shortcuts.md).

## AI hotkeys summary

- `CapsLock + A/S/T/E/W/F/X/R/G/D/Y/=` render prompt types in the AI Router flow
- `CapsLock + C` opens the agent chooser
- `CapsLock + Ctrl + W/I/G/X/H/C/L` are direct app/agent launch chords in this setup
- `CapsLock + Space` triggers AI workflow palette

For navigation, editing, direct launch, screenshot, and trackpad gesture details, see [Shortcut Reference](../../shortcuts.md).

## AI Router + Hammerspoon + Karabiner

1. Karabiner creates stable `CapsLock` chords.
2. Hammerspoon handles the event and triggers local automation.
3. AI Router renders prompt/agent actions using selected context.

Typical path: select text -> trigger caps command -> render -> paste/run via chooser.

## Quick checks

```bash
zsh -n home/.zshenv home/.config/zsh/*.zsh
bash -n home/.config/ai-router/ai-router.sh
python3 -m json.tool home/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json
bash tests/smoke/repository_structure_smoke.sh
```

For the full suite, run every script in `tests/smoke/` — see
[CONTRIBUTING.md](../../../CONTRIBUTING.md).
