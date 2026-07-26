# SketchyBar and Borders

`SketchyBar` plus `Borders` is the lightweight desktop UI layer for the AI-first workflow.

![SketchyBar workspace bar](../../../assets/screenshots/sketchybar-workspace-bar.png)

## Installed files

- `home/.config/sketchybar/`
- `home/.config/borders/`
- `bootstrap/install/sketchybar.sh`
- `bootstrap/install/borders.sh`

## What is included

- Left/center/right bar sections configured by `home/.config/sketchybar/sketchybarrc`.
- One theme file, `home/.config/sketchybar/theme.conf`, holding the fonts, sizes, geometry and colour roles. See [Theming](#theming).
- Runtime helper scripts in `home/.config/sketchybar/` and the border style in `home/.config/borders/bordersrc`.
- AeroSpace workspace integration via plugin callbacks.
- Workspace badges are assigned by display *role* - main, side, stage - rather than by monitor model. Which display plays which role, and how many workspaces exist, come from `~/.config/aerospace/displays.conf` and `~/.config/aerospace/workspaces.conf`; a single-display Mac resolves all three roles onto the one display.
- A role resolves to a SketchyBar arrangement ID through Hammerspoon screen UUID/DirectDisplayID metadata, so two external displays cannot swap bars when macOS renumbers them after login, lid open/close, or reconnect. Without Hammerspoon the resolver falls back to AeroSpace's monitor order and prints one line saying it did.
- `SKETCHYBAR_MAIN_MONITOR_NAME`, `SKETCHYBAR_SIDE_MONITOR_NAME` and `SKETCHYBAR_STAGE_MONITOR_NAME` still override the resolved names for a one-off run.
- AI attention indicators for selected tools and IDEs.
- `Option + Shift + Space` hides/shows SketchyBar on the main display through AeroSpace and also updates that display's outer gaps so captured windows reclaim or release the bar area.
- The battery item is display-aware by default: MacBooks with `InternalBattery` show battery status, while desktop Macs hide it automatically. Override with `SKETCHYBAR_SHOW_BATTERY=0`, `1`, or `auto`.
- Optional font fetch for the bar icon font and symbols.
- SbarLua is installed from a pinned upstream commit by `bootstrap/install/sketchybar.sh`; override `SBARLUA_REF` only when intentionally upgrading.

## Install and refresh

```bash
./bootstrap/install/sketchybar.sh
./bootstrap/install/borders.sh
brew services restart sketchybar
```

`Borders` is installed and its config is deployed, but the service is kept stopped by default. Start it explicitly with `BORDERS_START_SERVICE=1 ./bootstrap/install/borders.sh` or `brew services start borders`.

## Theming

Everything about how the bar looks lives in two files:

| File | Holds |
| --- | --- |
| `~/.config/sketchybar/colors.sh` | The palette. Three are shipped - Catppuccin is active, Sonokai and Tokyonight are commented out. |
| `~/.config/sketchybar/theme.conf` | Fonts, font sizes, bar and item geometry, and which palette entry plays which role. |

To restyle the bar:

1. Edit `~/.config/sketchybar/theme.conf` - for example `SKETCHYBAR_FONT_FAMILY`, `SKETCHYBAR_BAR_HEIGHT`, or `SKETCHYBAR_ACCENT_CLOCK`.
2. `brew services restart sketchybar` (or `sketchybar --reload`).

To swap the whole palette, uncomment one of the blocks in `colors.sh` and comment out the current one. Every role in `theme.conf` names a palette entry - `BLUE`, `MAGENTA`, `GREY` - so the roles move with it. A role can also be pinned to a literal `0xAARRGGBB`.

Both files survive upgrades: once your copy differs from the one the last install wrote, `./bootstrap/install/sketchybar.sh` reports `Kept local change` and leaves it alone. Run the installer with `--force` to take the shipped version back.

### The height the window manager has to reserve

A floating bar is not part of macOS's visible frame, so AeroSpace is told to leave room for it with an `outer.top` gap and Hammerspoon's Recording Mode reserves the same strip. That number is derived rather than written down:

```
SKETCHYBAR_BAR_TOP_INSET = SKETCHYBAR_BAR_HEIGHT + SKETCHYBAR_BAR_Y_OFFSET + SKETCHYBAR_BAR_MARGIN
```

which is `40 + 35 + 20 = 95` with the shipped values. Read it without reimplementing the arithmetic:

```bash
~/.config/sketchybar/lib/theme.sh get THEME_TOP_INSET
```

`theme.conf` is deliberately restricted to plain `KEY="value"` lines so Lua and Python can read it with a line matcher rather than a shell. Raising `SKETCHYBAR_BAR_HEIGHT` therefore only needs `outer.top` in `~/.aerospace.toml` to be re-rendered; set `SKETCHYBAR_BAR_TOP_INSET` explicitly if you want a different amount of clearance than the derived one.

## Running one half without the other

AeroSpace, SketchyBar and Hammerspoon are three separate installs, and any one of them can be missing:

| Missing | What happens |
| --- | --- |
| `aerospace` | Workspace chips stop being repainted and clicking one cannot switch workspaces; one line says so. Every other item on the bar keeps working. |
| `hs` | Display roles resolve through AeroSpace's monitor order instead of screen identity; one line says so, because the fallback can put a bar on the wrong screen after macOS renumbers displays. |
| `sketchybar` | AeroSpace's `Option + Shift + Space` degrades to "every display" instead of a per-display list, and says so. |

Which workspaces get a chip is resolved in this order: `SKETCHYBAR_WORKSPACES`, then `~/.config/aerospace/lib/layout.sh`, then `~/.config/aerospace/workspaces.conf`, then `aerospace list-workspaces --all`, then none. Set `SKETCHYBAR_WORKSPACES` in `theme.conf` to pin a list on a machine that has the bar but not this repo's AeroSpace config.

## Core behavior

- No user session state is tracked in this repo.
- SketchyBar plugin cache/sockets are runtime-only and recreated per machine.
- AI attention runtime state is stored in `~/Library/Caches/sketchybar/ai_attention.json`.
- Border style is reproducible from `bordersrc` and can be adjusted safely when Borders is enabled.

## AI Attention Notifications

The bar can show lightweight attention badges for:

- Warp
- Codex
- IntelliJ IDEA
- GoLand

The implementation is split deliberately:

- `home/.config/sketchybar/items/ai_notifications.sh` defines the hidden sync item, visible badges, popup rows, and click actions.
- `home/.config/sketchybar/plugins/ai_app_notifications.sh` reads macOS notification metadata, stores a local attention state, renders SketchyBar items, and reveals apps through AeroSpace.
- Hammerspoon does not read the macOS notification database. It only writes clear requests and asks SketchyBar to sync.

This avoids two common failure modes:

- SketchyBar hotload loops caused by writing runtime state under `~/.config/sketchybar`.
- Hammerspoon permission failures when trying to read macOS notification databases.

### Required macOS permission

To read notification metadata, SketchyBar needs Full Disk Access:

1. Open **System Settings -> Privacy & Security -> Full Disk Access**.
2. Add `/opt/homebrew/bin/sketchybar` or the resolved SketchyBar binary.
3. Restart SketchyBar:

```bash
brew services restart sketchybar
```

macOS does not allow this permission to be granted silently from an install script.

## Privacy notes

- `home/.config/sketchybar` does not include private account/session data.
- Runtime art assets and media cover fetches are not committed.
- Notification attention state is runtime-only and kept outside this repo.
- `BORDER` and bar configuration only references local paths and public binaries.
