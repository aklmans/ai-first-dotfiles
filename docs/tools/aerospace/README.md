# AeroSpace Workspace Management

AeroSpace is the desktop tiling engine for this setup.
It provides predictable workspace keys, quick window movement, and deterministic app placement for the desktop layer.

![AeroSpace tiling layout](../../../assets/screenshots/aerospace-tiling-layout.png)

## Installed files

- `home/.aerospace.toml`
- `home/.config/aerospace/displays.conf` - which monitor plays which role
- `home/.config/aerospace/workspaces.conf` - how many workspaces exist and where they live
- `home/.config/aerospace/lib/layout.sh` - the library every script reads those two through
- `home/.config/aerospace/render-layout.sh` - renders both into `~/.aerospace.toml`
- `home/.config/aerospace/*.sh`
- `bootstrap/install/aerospace.sh`
- `bootstrap/install/aerospace.sh` installs `aerospace`, deploys config, re-renders the generated blocks from your `displays.conf` / `workspaces.conf`, enables native ctrl-drag behavior, and tries a dry-run reload.

## What it does

- 13 workspaces by default: `1`–`12` for daily work and `13` as the recording/meeting stage. The count is config, not code - see below.
- Window-focused tiling and move commands are exposed as fast workspace shortcuts.
- SketchyBar and Borders integration uses scripts in `home/.config/aerospace/` to keep visible state aligned.
- Legacy `skhd`, `yabai`, `wezterm`, and `oh-my-posh` modules are **not included**.

## Displays and workspaces

Everything about your desk lives in two files, and nothing else names a monitor
or a workspace count:

| File | Answers |
|---|---|
| `~/.config/aerospace/displays.conf` | which physical monitor plays the `main`, `side` and `stage` role |
| `~/.config/aerospace/workspaces.conf` | which workspaces exist, and which role each one belongs to |

### One display works out of the box

`displays.conf` ships with all three roles empty, which means "resolve from
whatever is connected". On a MacBook with no external display, `main`, `side`
and `stage` all resolve to the built-in screen, every workspace lands there,
`Option + Shift + Space` hides that screen's bar, and `doctor.sh` is green.
Nothing waits at login for a display that is not there.

With two or three displays and no names configured, roles are handed out in the
order `aerospace list-monitors` reports them.

### Pinning a role to a specific monitor

Name the display when you want a role to follow one specific panel regardless of
enumeration order:

```bash
aerospace list-monitors          # exact names of what is connected
$EDITOR ~/.config/aerospace/displays.conf
~/.config/aerospace/render-layout.sh
```

A named display that is not connected costs nothing: its role falls back to the
next unclaimed monitor, and then onto `side` -> `main`, so one screen can carry
all three roles.

### Changing the number of workspaces

Edit the three lists in `workspaces.conf` and render once:

```bash
$EDITOR ~/.config/aerospace/workspaces.conf
~/.config/aerospace/render-layout.sh
```

That regenerates, inside the marked blocks of `~/.aerospace.toml`, the
persistent workspace list, the workspace-to-monitor assignment and the
`Ctrl + N` / `Ctrl + Shift + N` shortcuts, and re-renders the app placement
rules. Shortcut keys are handed out in order `1`-`9`, `0`, `[`, `]`, `\`;
workspaces past the fourteenth work but have no single-key shortcut. App rules
that ask for a workspace you removed are mapped onto the highest one you kept.

Everything outside the markers - your own bindings, your own comments - is left
untouched, so `render-layout.sh` is safe to run against a config you have
edited. `doctor.sh` reports when the config and the TOML have drifted apart.

## Default Workspace Map

Default role split:

- `main` display: workspaces `1`-`6`
- `side` display: workspaces `7`-`12`
- `stage` display (built-in, when there is one): workspace `13`

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
- `Option + Shift + Space` -> hide/show SketchyBar on the main display and compact/restore that display's AeroSpace outer gaps

The layout toggles are intentionally temporary one-shot commands. They help fix or adjust the current workspace without changing the default app rules used after restart or app relaunch. Repair preserves known utility/status windows as floating so they do not take half of a terminal or editor workspace.

Full shortcut map: [Shortcut Reference](../../shortcuts.md).

## Useful commands

```bash
bash -n home/.config/aerospace/*.sh
HOME="$PWD/home" bash home/.config/aerospace/app-defaults.sh
HOME="$PWD/home" bash home/.config/aerospace/check-display-layout.sh

# Is ~/.aerospace.toml still what displays.conf and workspaces.conf render?
~/.config/aerospace/render-layout.sh --check
```

If available on your machine:

```bash
aerospace reload-config --dry-run --no-gui
```

## File rules and behavior

- `displays.conf` and `workspaces.conf` are deployed like any other config file, which means the deploy engine keeps your edits: a redeploy only overwrites a file this repo itself has changed, and backs up whatever it replaces.
- The generated blocks of `~/.aerospace.toml` are re-rendered from your two config files after every deploy, so an update to the tracked TOML does not quietly reset your workspace count or your monitor names.
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
