# Hammerspoon Automation

Hammerspoon is the event and workflow glue that connects keyboard shortcuts, AeroSpace state, and AI Router commands.

![Coding agent chooser](../../../assets/screenshots/agent-chooser.png)

## Installed files

- `home/.hammerspoon/init.lua`
- `home/.hammerspoon/ai_hotkeys.lua`
- `home/.hammerspoon/app_reveal.lua`
- `home/.hammerspoon/screencast.lua`
- `bootstrap/install/hammerspoon.sh`

## Install

```bash
./bootstrap/install/hammerspoon.sh
```

Open Hammerspoon and allow Accessibility + Automation permissions.

Loading/reloading config no longer installs `hs` or changes launch-at-login.
Make these optional, one-time choices explicitly in Hammerspoon Console:

```lua
require("hs.ipc").cliInstall() -- CLI integration, if wanted
hs.autoLaunch(true)           -- launch at login, if wanted
```

Existing CLI/login settings are left alone, not automatically reversed.

## Key responsibilities

- Launch/activate desktop windows and recover workspace focus.
- Provide fallback prompt chooser behavior when dynamic catalogs are not available.
- Execute AI Router actions from CapsLock hotkeys.
- Clear SketchyBar AI attention badges when tracked apps become active.
- Reveal tracked app windows through AeroSpace after app activation events.
- Resize the focused window into predictable screencast recording frames.
- Keep chooser tools deterministic and local.

## Runtime behavior

- Uses tracked config in `~/.hammerspoon`.
- Reads catalog/data from `~/.config/ai-router/`.
- Writes AI attention clear requests through `~/.config/sketchybar/plugins/ai_app_notifications.sh`.
- Does not read the macOS notification database directly.
- Window/attention event logging is off by default; even opt-in diagnostics
  contain only event codes and exit status, never window titles or raw errors.
  See [diagnostics and legacy logs](../../privacy.md#window-diagnostics).

## AI attention bridge

Hammerspoon watches focused windows and application activation events for:

- Warp
- Codex
- IntelliJ IDEA
- GoLand

When one of these apps becomes active, Hammerspoon writes a clear request and triggers the SketchyBar sync event. SketchyBar then clears the local status-bar badge using its own runtime state and notification database access.

## Script checks

```bash
lua -e "assert(loadfile('home/.hammerspoon/init.lua'))"
lua -e "assert(loadfile('home/.hammerspoon/ai_hotkeys.lua'))"
```

## Core interaction with other modules

- **Karabiner** creates `CapsLock` chords.
- **AeroSpace** provides workspace commands and window IDs for focus/move logic.
- **AI Router** executes render/run commands and agent chooser actions.

## Screencast window presets

The screencast helper temporarily sets the focused window to AeroSpace floating, then applies a centered recording frame. Recording Mode additionally moves the focused window to the configured semantic `stage` workspace, hides SketchyBar, applies the compact outer gaps, and opens Camtasia or Snagit when available. The read-only `recording-target.sh` resolves the profile and overlays on each invocation: `author-full` uses workspace `13`, while a custom profile can put the recording role on any configured workspace, including one on its main display. Invalid targets stop without moving the window.

Move, bar/gaps and float failures stop the chain. A resize is checked by reading
the resulting frame, with a 3-point tolerance; apps may impose minimum sizes.
Commands have a 15-second watchdog and task-start failures are reported.
Earlier steps can remain applied on failure; there is no automatic window or
bar rollback. Exit restores bar/gaps, **not** tiling or the original workspace.
Recording Mode's explicit `hide` applies to all bars; Option+Shift+Space remains
main-only. If SketchyBar is absent, visibility is skipped and only gaps change.
Dimensions are macOS logical points, not guaranteed encoded video pixels.
Preparing a window does not start capture or verify resolution, audio or privacy.

| Shortcut | Action |
|---|---|
| `Ctrl + Alt + Cmd + M` | Enter Recording Mode |
| `Ctrl + Alt + Cmd + Shift + M` | Exit Recording Mode |
| `Ctrl + Alt + Cmd + R` | 720p recording frame |
| `Ctrl + Alt + Cmd + F` | Largest centered 16:9 frame |
| `Ctrl + Alt + Cmd + 0` | Preset chooser, including Recording Mode on/off |
| `Ctrl + Alt + Cmd + T` | Restore focused window to tiling |

## Notes

- Do not add blocking `hs.execute` logic in local customizations.
- Keep external command invocation explicit and idempotent.
