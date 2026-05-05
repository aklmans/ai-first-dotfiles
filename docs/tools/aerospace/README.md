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

- 12 workspaces by default (`1`–`12`, where `[` is `11`, `]` is `12`).
- Window-focused tiling and move commands are exposed as fast workspace shortcuts.
- SketchyBar and Borders integration uses scripts in `home/.config/aerospace/` to keep visible state aligned.
- Legacy `skhd`, `yabai`, `wezterm`, and `oh-my-posh` modules are **not included**.

## Default Workspace Map

| Workspace | Default role | Tracked apps |
|---|---|---|
| `1` | Dia browser | Dia |
| `2` | Edge browser | Microsoft Edge |
| `3` | Codex app | Codex |
| `4` | ChatGPT app | ChatGPT |
| `5` | IM | WeChat, WeCom, QQ, DingTalk, Feishu/Lark, Zoom, Discord |
| `6` | macOS system | Finder, System Settings, Activity Monitor, Mail, Preview, Photos, App Store |
| `7` | Warp terminal | Warp |
| `8` | JetBrains IDEs | IntelliJ IDEA, GoLand, WebStorm, DataGrip, PyCharm, CLion, Rider, Android Studio |
| `9` | Atlas browser | ChatGPT Atlas |
| `10` | Writing and notes | Typora, MiaoYan |
| `11` | Auxiliary tools | Chrome, Safari, Firefox, VS Code, Sublime Text, Cursor, Kaku, Camtasia, Snagit |
| `12` | Background utilities | Clash for Windows, Logi Options+, Docker Desktop, Loopback |

## Core hotkeys

These are the workspace-level shortcuts documented in this repo:

- `Ctrl + 1..0` -> switch workspace 1..10
- `Ctrl + [` / `Ctrl + ]` -> switch workspace 11/12
- `Ctrl + Shift + 1..0` -> move focused window to workspace 1..10
- `Ctrl + Shift + [` / `Ctrl + Shift + ]` -> move focused window to workspace 11/12
- `Ctrl + Left/Right` -> cycle workspace groups by monitor split logic
- `Alt + H/J/K/L` -> move focus inside the active layout
- `Alt + Shift + T` -> toggle focused window floating/tiling
- `Alt + Shift + A` -> toggle the focused app's current-workspace windows floating/tiling
- `Alt + Shift + W` -> toggle all windows in the current workspace floating/tiling
- `Alt + Shift + R` -> repair current workspace: default tiling/floating, flatten tree, tiles layout, balance sizes
- `Option + Shift + Space` -> hide/show SketchyBar and compact/restore the AeroSpace top gap

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
- `home/.config/aerospace/warp-launch-agent.sh` is intentionally not tracked.
- `home/.config/aerospace/layout-control.sh` owns temporary layout repair/toggle actions so shortcuts do not rely on multi-command inline AeroSpace chains.
- `home/.config/aerospace/reveal-app.sh` jumps to and focuses the workspace window for a bundle id. SketchyBar AI attention badges use it for app reveal actions.
- `home/.config/aerospace/toggle-sketchybar-space.sh` keeps SketchyBar visibility and AeroSpace `outer.top` in sync. Hidden mode uses a compact top gap; visible mode restores the display-aware bar gap.
- `home/.config/ai-router/...` runtime data is intentionally excluded.

## Relationship to other modules

- **SketchyBar** consumes workspace events to display current workspace.
- **Hammerspoon** reads window/focus changes and keeps some cross-workspace behavior consistent.
- **Karabiner** provides the `Ctrl` chords via hardware-level remaps.
