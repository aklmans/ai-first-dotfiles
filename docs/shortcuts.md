# Shortcut Reference

This page is the canonical shortcut map for the tracked setup.

`CapsLock` is configured by Karabiner:

- Tap `CapsLock` -> `Esc`
- Hold `CapsLock` -> Hyper (`Command + Control + Option + Shift`)

In this document, `CapsLock + key` means hold `CapsLock`, then press `key`.
`Alt` in AeroSpace config is the macOS `Option` key.

## Workspaces

Workspace behavior is owned by `home/.aerospace.toml`.

| Workspace | Default role |
|---|---|
| `1` | Dia |
| `2` | Microsoft Edge |
| `3` | Codex app |
| `4` | ChatGPT app |
| `5` | IM apps |
| `6` | Finder and macOS system apps |
| `7` | Warp |
| `8` | JetBrains IDEs |
| `9` | ChatGPT Atlas |
| `10` | Typora and MiaoYan |
| `11` | Auxiliary browsers/editors/tools |
| `12` | Background utilities |

| Shortcut | Action |
|---|---|
| `Ctrl + 1..0` | Switch to workspace `1..10` |
| `Ctrl + [` / `Ctrl + ]` | Switch to workspace `11` / `12` |
| `Ctrl + Shift + 1..0` | Move focused window to workspace `1..10` and follow it |
| `Ctrl + Shift + [` / `Ctrl + Shift + ]` | Move focused window to workspace `11` / `12` and follow it |
| `Ctrl + Left` / `Ctrl + Right` | Move to previous / next workspace group |
| `Alt + Tab` | Toggle back to the previously focused workspace |
| `Ctrl + Up` | Mission Control |
| `Ctrl + Down` | App Expose |

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
| `Alt + Shift + T` | Toggle floating / tiling |
| `Alt + Shift + V` | Use tiles layout |
| `Alt + Shift + X` | Split vertically for the next tiled window |
| `Alt + Shift + Y` | Split horizontally for the next tiled window |
| `Alt + F` | Toggle AeroSpace fullscreen |
| `Ctrl + Alt + F` | Toggle AeroSpace fullscreen |
| `Alt + Shift + F` | Toggle native macOS fullscreen |
| `Alt + Shift + R` | Flatten workspace tree and reset layout |

## Displays And Desktop UI

| Shortcut | Action |
|---|---|
| `Alt + S` / `Alt + G` | Focus left / right display |
| `Alt + Shift + S` / `Alt + Shift + G` | Move focused window to left / right display |
| `Option + Shift + Space` | Toggle SketchyBar visibility and matching AeroSpace top gap |
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
- `home/.config/karabiner/karabiner.json`: CapsLock Hyper, navigation, editing, global chords, launchers.
- `home/.hammerspoon/ai_hotkeys.lua`: AI Router chooser, prompt hotkeys, agent chooser.
- `home/.config/bettertouchtool/aerospace-gestures.sh`: trackpad gestures.
