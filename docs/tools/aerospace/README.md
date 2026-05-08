# AeroSpace Workspace Management

AeroSpace is the desktop tiling engine for this setup.
It provides predictable workspace keys, quick window movement, and deterministic app placement for the desktop layer.

![AeroSpace tiling layout](../../../assets/screenshots/aerospace-tiling-layout.png)

## Installed files

- `home/.aerospace.toml`
- `home/.config/aerospace/*.sh`
- `bootstrap/install/aerospace.sh`
- `bootstrap/install/aerospace.sh` installs `aerospace`, deploys config, enables native ctrl-drag behavior, and tries a dry-run reload.

## What it does

- 13 workspaces by default: `1`–`12` for daily work and `13` for the built-in display recording/meeting stage.
- Window-focused tiling and move commands are exposed as fast workspace shortcuts.
- SketchyBar and Borders integration uses scripts in `home/.config/aerospace/` to keep visible state aligned.
- Legacy `skhd`, `yabai`, `wezterm`, and `oh-my-posh` modules are **not included**.

## Default Workspace Map

Default monitor split:

- `PHL 279C9` / 27-inch main display: workspaces `1`-`6`
- `24V5C2` / 24-inch side display: workspaces `7`-`12`
- `Built-in Retina Display`: workspace `13`

| Workspace | Default role | Tracked apps |
|---|---|---|
| `1` | Warp terminal | Warp |
| `2` | JetBrains IDEs | IntelliJ IDEA, GoLand, WebStorm, DataGrip, PyCharm, CLion, Rider, Android Studio |
| `3` | Codex app | Codex |
| `4` | ChatGPT app | ChatGPT |
| `5` | Claude app | Claude |
| `6` | Dia browser | Dia |
| `7` | Edge browser | Microsoft Edge |
| `8` | Atlas browser | ChatGPT Atlas |
| `9` | Writing and notes | Typora, MiaoYan, Markdown, MarkEditor |
| `10` | IM | WeChat, WeCom, QQ, DingTalk, Feishu/Lark, Discord |
| `11` | macOS system | Finder, System Settings, Activity Monitor, Mail, Preview, Photos, App Store |
| `12` | Background utilities | Clash for Windows, Logi Options+, Docker Desktop, Loopback |
| `13` | Recording / meeting / presentation stage | Camtasia, Snagit, Zoom, Lark Meetings |

## Core hotkeys

These are the workspace-level shortcuts documented in this repo:

- `Ctrl + 1..0` -> switch workspace 1..10
- `Ctrl + [` / `Ctrl + ]` -> switch workspace 11/12
- `Ctrl + \` -> switch workspace 13
- `Ctrl + Shift + 1..0` -> move focused window to workspace 1..10
- `Ctrl + Shift + [` / `Ctrl + Shift + ]` -> move focused window to workspace 11/12
- `Ctrl + Shift + \` -> move focused window to workspace 13
- `Ctrl + Left/Right` -> cycle workspace groups by monitor split logic
- `Alt + H/J/K/L` -> move focus inside the active layout
- `Alt + Shift + T` -> toggle focused window floating/tiling
- `Alt + Shift + A` -> toggle the focused app's current-workspace windows floating/tiling
- `Alt + Shift + W` -> toggle all windows in the current workspace floating/tiling
- `Alt + Shift + R` -> repair current workspace: default tiling/floating, flatten tree, tiles layout, balance sizes
- `Option + Shift + Space` -> hide/show SketchyBar on the main display and compact/restore that display's AeroSpace top gap

The layout toggles are intentionally temporary one-shot commands. They help fix or adjust the current workspace without changing the default app rules used after restart or app relaunch. Repair preserves known utility/status windows as floating so they do not take half of a terminal or editor workspace.

Full shortcut map: [Shortcut Reference](../../shortcuts.md).

## Useful commands

```bash
bash -n home/.config/aerospace/*.sh
HOME="$PWD/home" bash home/.config/aerospace/app-defaults.sh
HOME="$PWD/home" bash home/.config/aerospace/check-display-layout.sh
```

If available on your machine:

```bash
aerospace reload-config --dry-run --no-gui
```

## File rules and behavior

- App placement defaults are intentionally generated from tracked config, not from local session state.
- Agent launch shortcuts use the tracked AI Router `agent` command, which opens a new Warp tab and pastes the command without executing it.
- `home/.config/aerospace/layout-control.sh` owns temporary layout repair/toggle actions so shortcuts do not rely on multi-command inline AeroSpace chains.
- `home/.config/aerospace/reveal-app.sh` jumps to and focuses the workspace window for a bundle id. SketchyBar AI attention badges use it for app reveal actions.
- `home/.config/aerospace/toggle-sketchybar-space.sh` keeps SketchyBar visibility and AeroSpace `outer.top` in sync. The default shortcut targets the main display only for livestream capture. Explicit `hide` / `show` modes still hide or restore all displays for Recording Mode and scripted workflows.
- `home/.config/ai-router/...` runtime data is intentionally excluded.

## Relationship to other modules

- **SketchyBar** consumes workspace events to display current workspace.
- **Hammerspoon** reads window/focus changes and keeps some cross-workspace behavior consistent.
- **Karabiner** provides the `Ctrl` chords via hardware-level remaps.
