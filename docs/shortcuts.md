# Shortcut Reference

This page is the canonical shortcut map for the tracked setup.

`CapsLock` is configured by Karabiner:

- Tap `CapsLock` -> `Esc`
- Hold `CapsLock` -> Hyper (`Command + Control + Option + Shift`)

In this document, `CapsLock + key` means hold `CapsLock`, then press `key`.
`Alt` in AeroSpace config is the macOS `Option` key.

> **Some of these collide with macOS defaults**, most notably `Ctrl + ←/→` and
> the CapsLock key itself. See
> [Shortcuts that fight macOS](../README.md#shortcuts-that-fight-macos) before
> concluding a binding is broken.

## Workspaces

Workspace behavior is owned by `home/.aerospace.toml`. `minimal` creates neutral
workspaces 1–6 and disables automatic app placement. The role table below is the
`author-full` reference map, not a requirement for other presets.

| Workspace | Default role |
|---|---|
| `1` | Warp |
| `2` | JetBrains IDEs |
| `3` | Codex app |
| `4` | ChatGPT app |
| `5` | Claude app |
| `6` | Dia |
| `7` | Microsoft Edge |
| `8` | ChatGPT Atlas |
| `9` | Writing apps |
| `10` | IM apps |
| `11` | macOS system apps; Finder and Preview follow the current workspace |
| `12` | Background utilities |
| `13` | Recording / meeting / presentation stage |

| Shortcut | Action |
|---|---|
| `Ctrl + 1..6` | Switch to workspace `1..6` in every preset |
| `Ctrl + 7..0` | Switch to workspace `7..10` when configured |
| `Ctrl + [` / `Ctrl + ]` | Switch to workspace `11` / `12` when configured |
| `Ctrl + \` | Switch to workspace `13` when configured |
| `Ctrl + Shift + <workspace key>` | Move the focused window to that configured workspace and follow it |
| `Ctrl + Left` / `Ctrl + Right` | Move to previous / next workspace group |
| `Alt + Tab` | Toggle back to the previously focused workspace |
| `Ctrl + Up` | Mission Control — **requires BetterTouchTool** (`setup.sh gestures`) |
| `Ctrl + Down` | App Exposé — **requires BetterTouchTool** (`setup.sh gestures`) |

## Window Focus And Layout

| Shortcut | Action |
|---|---|
| `Alt + H/J/K/L` | Focus window left / down / up / right |
| `Alt + Shift + H/J/K/L` | Swap focused window left / down / up / right |
| `Ctrl + Alt + H/J/K/L` | Move focused window left / down / up / right |
| `Ctrl + Alt + Left/Right` | Decrease / increase window width |
| `Ctrl + Alt + Up/Down` | Decrease / increase window height |
| `Alt + -` / `Alt + =` | Smart resize smaller / larger |
| `Alt + Shift + E` | Balance tiled window sizes |
| `Alt + /` | Toggle tiles layout orientation |
| `Alt + ,` | Toggle accordion layout orientation |
| `Alt + Shift + T` | Toggle focused window floating / tiling |
| `Alt + Shift + A` | Toggle windows from the focused app in the current workspace floating / tiling |
| `Alt + Shift + W` | Toggle all windows in the current workspace floating / tiling |
| `Alt + Shift + V` | Use tiles layout |
| `Alt + Shift + X` | Split vertically for the next tiled window |
| `Alt + Shift + Y` | Split horizontally for the next tiled window |
| `Alt + F` | Toggle AeroSpace fullscreen |
| `Ctrl + Alt + F` | Toggle AeroSpace fullscreen |
| `Alt + Shift + F` | Toggle native macOS fullscreen |
| `Alt + Shift + R` | Repair current workspace: restore default tiling/floating, flatten tree, tiles layout, balance sizes |
| `Option + Shift + B` | Persistently bind the focused app to the current workspace |
| `Option + Shift + U` | Persistently unpin the focused app so new windows stay where opened |

The layout commands are one-shot operations. `Option + Shift + B/U` are the
exception: they update the focused app's persistent route, back up the old route
file, render the AeroSpace rules and reload them. Finder and Preview ship as
unpin/follow-current while remaining floating. Repair keeps known utility/status
windows floating so they do not consume tiling space.

## Displays And Desktop UI

| Shortcut | Action |
|---|---|
| `Alt + S` / `Alt + G` | Focus left / right display |
| `Alt + Shift + S` / `Alt + Shift + G` | Move focused window to left / right display |
| `Option + Shift + Space` | Toggle SketchyBar only on the main display and compact/restore that display's outer gaps |
| `Ctrl + Alt + 0` | Reset tracked apps to default workspaces |
| `Ctrl + Alt + R` | Reload AeroSpace config and SketchyBar |
| `Ctrl + Alt + S` | Reload AeroSpace config |
| `Ctrl + Alt + Y` | Toggle AeroSpace enable state |

## Trackpad Gestures

BetterTouchTool owns the portable gesture preset in `home/.config/bettertouchtool/aerospace-gestures.sh`.

| Gesture | Action |
|---|---|
| 3-finger swipe left | Next AeroSpace workspace group |
| 3-finger swipe right | Previous AeroSpace workspace group |
| 4-finger swipe left | Next AeroSpace workspace group |
| 4-finger swipe right | Previous AeroSpace workspace group |
| 3-finger swipe up | Mission Control |
| 4-finger swipe up | Mission Control |
| 3-finger swipe down | App Expose |
| 4-finger swipe down | App Expose |

## Sublime Text

Sublime Text bindings are deployed by `bootstrap/install/sublime.sh`.

| Shortcut | Action |
|---|---|
| `Cmd + B` | Toggle sidebar |
| `Cmd + 1` | Focus sidebar |
| `Cmd + 2` | Open current file/project directory in Warp |
| `Cmd + 3` | Find in files |
| `Cmd + E` | Reveal current file in sidebar |
| `Cmd + Shift + E` | Reveal current file in Finder |
| `Cmd + Shift + C` | Copy current file path |

## Screencast Window Presets

Hammerspoon applies these presets to the focused window. The window is temporarily set to AeroSpace floating before it is resized, so the recording frame stays predictable.

| Shortcut | Action |
|---|---|
| `Ctrl + Alt + Cmd + M` | Enter Recording Mode: move the focused window to workspace `13`, hide SketchyBar, fit a 16:9 stage, and open Camtasia/Snagit |
| `Ctrl + Alt + Cmd + Shift + M` | Exit Recording Mode: restore SketchyBar and the normal AeroSpace outer gaps |
| `Ctrl + Alt + Cmd + R` | Set focused window to a 720p recording size |
| `Ctrl + Alt + Cmd + F` | Set focused window to the largest centered 16:9 recording region on the current display |
| `Ctrl + Alt + Cmd + 0` | Open screencast preset chooser, including Recording Mode on/off |
| `Ctrl + Alt + Cmd + T` | Restore focused window to AeroSpace tiling |

## CapsLock Navigation

These chords work anywhere Karabiner is active.

| Shortcut | Output |
|---|---|
| `CapsLock + H/J/K/L` | Left / down / up / right arrow |
| `CapsLock + U` | Page Up |
| `CapsLock + I` | Home |
| `CapsLock + O` | End |
| `CapsLock + P` | Page Down |
| `CapsLock + Option + H/L` | Option + left / right arrow |
| `CapsLock + Command + H/J/K/L` | Shift + left / down / up / right arrow |
| `CapsLock + Command + Option + H/L` | Option + Shift + left / right arrow |

## CapsLock Editing

| Shortcut | Output |
|---|---|
| `CapsLock + M` | Delete previous character |
| `CapsLock + ,` | Delete next character |
| `CapsLock + N` | Delete previous word |
| `CapsLock + .` | Delete next word |
| `CapsLock + Command + N` | Delete to line start |
| `CapsLock + Command + .` | `Control + K` / delete to line end in most macOS text fields |

## AI Router Prompt Layer

Hammerspoon receives these chords and calls AI Workflow Router.
The default behavior renders a prompt with the current selection and copies the result to the clipboard.

| Shortcut | Action |
|---|---|
| `CapsLock + Space` | Open AI workflow palette |
| `CapsLock + C` | Open coding agent chooser |
| `CapsLock + A` | Ask AI |
| `CapsLock + S` | Summarize selection |
| `CapsLock + T` | Translate selection |
| `CapsLock + E` | Explain selection |
| `CapsLock + W` | Rewrite selection |
| `CapsLock + F` | Fix selection |
| `CapsLock + X` | Extract key points |
| `CapsLock + R` | Research plan |
| `CapsLock + G` | Generate content |
| `CapsLock + D` | Draft message |
| `CapsLock + Y` | Translate Chinese to English |
| `CapsLock + =` | Optimize prompt |

The agent chooser includes Codex CLI, Claude Code, Junie, Gemini CLI, Kimi CLI, Warp Agent, and Codex App entries from `home/.config/ai-router/config.json`.

## Direct App And Agent Launchers

Karabiner handles these directly. They do not require the Hammerspoon chooser.

| Shortcut | Action |
|---|---|
| `CapsLock + Ctrl + W` | Open Warp |
| `CapsLock + Ctrl + I` | Open IntelliJ IDEA |
| `CapsLock + Ctrl + G` | Open GoLand |
| `CapsLock + Ctrl + X` | Open Codex App |
| `CapsLock + Ctrl + H` | Open ChatGPT |
| `CapsLock + Ctrl + C` | Start Codex CLI through AI Router |
| `CapsLock + Ctrl + L` | Start Claude Code through AI Router |

## Global AI And App Entry Chords

Karabiner also emits stable global chords for external tools such as Raycast, Keyboard Maestro, Shortcuts, or a future dedicated AI resource manager.

| Shortcut | Output |
|---|---|
| `CapsLock + A/S/W/T/E/R/G/F/X/C/D/Z` | `Control + Option + Command + Shift + same key` |
| `CapsLock + Space` | `Control + Option + Command + Shift + Space` |
| `CapsLock + B/V/Q` | `Control + Option + Command + Shift + B/V/Q` |
| `CapsLock + ;` | `Control + Option + Command + Shift + ;` |
| `CapsLock + '` | `Control + Option + Command + Shift + '` |

When Hammerspoon is running, its AI Router bindings consume the prompt-related chords first.

## Screenshot Entry Chords

| Shortcut | Output | Suggested binding |
|---|---|---|
| ``CapsLock + ` `` | ``Control + Option + Command + Shift + ` `` | Screenshot |
| ``CapsLock + Command + ` `` | `Control + Option + Command + Shift + 1` | OCR screenshot |
| ``CapsLock + Shift + ` `` | `Control + Option + Command + Shift + 2` | Beautify screenshot |

## Config Files

- `home/.aerospace.toml`: workspace, window, display, and desktop UI shortcuts.
  The workspace and `Ctrl + N` blocks are generated — edit
  `~/.config/aerospace/workspaces.conf` and run `render-layout.sh` instead.
- `home/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json`:
  CapsLock Hyper, navigation, editing, global chords, launchers. **This is the
  file that gets installed**, as a Karabiner complex-modification rule you enable
  yourself.
- `home/.config/karabiner/karabiner.json`: a reference copy of the profile those
  rules produce. Never deployed — Karabiner rewrites that file itself, and
  overwriting it would replace every profile and device override you have.
- `home/.hammerspoon/ai_hotkeys.lua`: AI Router chooser, prompt hotkeys, agent chooser.
- `home/.hammerspoon/screencast.lua`: focused-window recording size presets.
- `home/.config/bettertouchtool/aerospace-gestures.sh`: trackpad gestures.
