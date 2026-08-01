# AeroSpace Workspace Management

AeroSpace is the desktop tiling engine for this setup.
It provides predictable workspace keys, quick window movement, and deterministic app placement for the desktop layer.

![AeroSpace tiling layout](../../../assets/screenshots/aerospace-tiling-layout.png)

## Installed files

- `home/.aerospace.toml`
- `home/.config/aerospace/displays.conf` - which monitor plays which role
- `home/.config/aerospace/workspaces.conf` - how many workspaces exist and where they live
- `home/.config/aerospace/routing-packs/` - optional shipped placement policies
- `home/.config/aerospace/lib/layout.sh` - the library every script reads those two through
- `home/.config/aerospace/render-layout.sh` - renders both into `~/.aerospace.toml`
- `home/.config/aerospace/render-app-rules.sh` - renders user `app-routes.conf` overrides and shipped defaults into `~/.aerospace.toml`
- `home/.config/aerospace/doctor.sh` - reports where the desk, the config and the TOML disagree
- `home/.config/aerospace/plan.sh` - previews resolved displays, semantic roles and routes
- `bootstrap/advisor.sh` - detects a desk and generates a reviewed local profile
- `home/.config/aerospace/*.sh`
- `bootstrap/install/aerospace.sh` installs `aerospace`, deploys config, re-renders the generated blocks from your `displays.conf` / `workspaces.conf`, enables native ctrl-drag behavior, and tries a dry-run reload.

### The two generators

`~/.aerospace.toml` is partly generated. Two scripts own the marked blocks
inside it, and everything outside those markers — your own bindings, your own
comments — is left untouched, so both are safe to run against a config you have
edited by hand.

| Script | Reads | Writes into `~/.aerospace.toml` |
|---|---|---|
| `render-layout.sh` | `displays.conf`, `workspaces.conf` | Persistent workspace list, workspace-to-monitor assignment, the `Ctrl + N` and `Ctrl + Shift + N` bindings. Then calls `render-app-rules.sh` unless given `--no-app-rules`. |
| `render-app-rules.sh` | generic layout rules, handwritten/captured/advisor routes, selected routing pack | Dialog behavior, exact local overrides and optional shipped placement |

`render-layout.sh --check` reports drift, exits 1 when the TOML is out of date,
and changes nothing — usually the fastest answer to "did my edit take?":

```bash
~/.config/aerospace/render-layout.sh --check
```

`render-app-rules.sh` takes an optional path and always writes; it keeps the
previous file next to the target as `.bak-<timestamp>-render-app-rules`.

Edit the `.conf` files, especially `app-routes.conf`, not generated blocks — the next
render replaces them.

## What it does

- 13 workspaces by default: `1`–`12` for daily work and `13` as the recording/meeting stage. The count is config, not code - see below.
- Window-focused tiling and move commands are exposed as fast workspace shortcuts.
- SketchyBar and Borders integration uses scripts in `home/.config/aerospace/` to keep visible state aligned.

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
workspaces past the fourteenth work but have no single-key shortcut. Semantic
app targets are resolved through `AEROSPACE_WORKSPACE_ROLE_MAP`; missing targets
are reported instead of being crowded onto the highest workspace.

Everything outside the markers - your own bindings, your own comments - is left
untouched, so `render-layout.sh` is safe to run against a config you have
edited. `doctor.sh` reports when the config and the TOML have drifted apart.

## Guided layout and feedback

The installer can recommend rather than assume a desk:

```bash
./bootstrap/setup.sh recommend             # local detection + preview
./bootstrap/setup.sh recommend --apply     # confirm, generate, install
./bootstrap/setup.sh tune                  # explicit fewer/keep/more feedback
```

Workspace count follows selected task scenes, not display count alone. The
advisor offers `focus` (4), `balanced` (6), `multitask` (8) and `advanced` (10),
then distributes them across the displays currently detected. `flexible` keeps
monitor names empty so roles collapse when screens are unplugged. `fixed` asks
the user before writing detected display names.

Installed-app suggestions are exact bundle-id data under
`~/.config/ai-first/advisor-routes.conf`. They contain only applications found
locally in selected scenes. The detection result itself is not persisted.

After using the desk, arrange windows naturally and take a one-time snapshot:

```bash
~/.config/aerospace/app-route.sh capture-current
~/.config/aerospace/app-route.sh capture-current --policy fixed --apply
```

The first command previews. An app observed across several workspaces is
proposed as `follow`; one concentrated in a configured workspace is proposed as
semantic `prefer` when its task role matches (or the exact workspace otherwise)
by default. Applying writes
`~/.config/ai-first/captured-routes.conf`. No watcher, event log or background
history is enabled.

Route priority is handwritten `app-routes.conf`, captured desktop, install
advisor, then shipped pack. `plan.sh` displays and validates every layer.

## Author reference Workspace Map

The table below belongs to `author-full`, not to the public `developer` preset.
`developer` enables routing support but selects pack `none`, so applications
stay where opened until the user chooses a route.

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
| `5` | Assistant | Cola |
| `6` | Dia browser | Dia |
| `7` | Edge browser | Microsoft Edge |
| `8` | Atlas browser | ChatGPT Atlas |
| `9` | Writing and notes | Typora, MiaoYan, Markdown, MarkEditor |
| `10` | IM | WeChat, WeCom, QQ, DingTalk, Feishu/Lark, Discord |
| `11` | macOS system | System Settings, Activity Monitor, Mail, Photos, App Store |
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
- `Option + Shift + B` -> bind the focused app to the current workspace
- `Option + Shift + U` -> let the focused app follow the workspace where it is opened
- `Option + Shift + Space` -> hide/show SketchyBar on the main display and compact/restore that display's AeroSpace outer gaps

The layout toggles are intentionally temporary one-shot commands. They help fix or adjust the current workspace without changing the default app rules used after restart or app relaunch. The two app-route shortcuts are persistent: they update `app-routes.conf`, keep a backup, render and reload the config. Finder and Preview default to following the workspace that opened them while remaining floating. Repair preserves known utility/status windows as floating so they do not take half of a terminal or editor workspace.

Full shortcut map: [Shortcut Reference](../../shortcuts.md).

## Useful commands

```bash
~/.config/aerospace/app-route.sh bind-here  # pin focused app here
~/.config/aerospace/app-route.sh follow     # stay where opened
~/.config/aerospace/app-route.sh prefer notes # prefer a semantic task role
~/.config/aerospace/app-route.sh capture-current # preview routes from this desktop
~/.config/aerospace/app-route.sh forget     # restore shipped default
~/.config/aerospace/app-route.sh list       # inspect custom routes
~/.config/aerospace/plan.sh                 # preview the complete resolution

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
- App placement is selected by `AI_FIRST_ROUTING_PACK`; `none` is portable,
  `creator` targets the semantic stage, and `author` preserves the reference desk.
- Machine-aware advice and a captured desktop are separate generated route
  layers below handwritten `app-routes.conf`; neither is background telemetry.
- Agent launch shortcuts use the tracked AI Router `agent` command, which opens a new Warp tab and pastes the command without executing it.
- `home/.config/aerospace/layout-control.sh` owns temporary layout repair/toggle actions so shortcuts do not rely on multi-command inline AeroSpace chains.
- `home/.config/aerospace/app-route.sh` captures the focused app for persistent bind/follow/prefer choices, with an exact-match data rule and backup on every change.
- `home/.config/aerospace/reveal-app.sh` jumps to and focuses the workspace window for a bundle id. SketchyBar AI attention badges use it for app reveal actions.
- `home/.config/aerospace/toggle-sketchybar-space.sh` keeps SketchyBar visibility and AeroSpace `outer.top` in sync. The default shortcut targets the main display only for livestream capture. Explicit `hide` / `show` modes still hide or restore all displays for Recording Mode and scripted workflows.
- `home/.config/ai-router/...` runtime data is intentionally excluded.

## Relationship to other modules

- **SketchyBar** consumes workspace events to display current workspace.
- **Hammerspoon** reads window/focus changes and keeps some cross-workspace behavior consistent.
- **Karabiner** provides the `Ctrl` chords via hardware-level remaps.
