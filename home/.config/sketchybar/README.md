## SketchyBar Configuration

This directory contains a public, reusable SketchyBar setup and plugin layout.

Layout:

- `theme.conf` - fonts, sizes, geometry and colour roles. The one file to edit to restyle the bar.
- `colors.sh` - the palette the roles in `theme.conf` refer to.
- `icons.sh` - the glyphs.
- `lib/theme.sh` - loads `colors.sh` and then `theme.conf`, and derives everything else, including the top inset AeroSpace and Hammerspoon have to agree with.
- `lib/workspaces.sh` - which workspaces get a chip, asked of `~/.config/aerospace/` with fallbacks.
- `lib/display-resolver.sh` - monitor name to SketchyBar display id, through Hammerspoon when it is installed and AeroSpace when it is not.
- `lib/runtime.sh` - where `aerospace`, `hs` and `sketchybar` are, and how a missing one is reported.
- `items/` - what is on the bar. `plugins/` - what keeps it up to date.

The libraries fork no subprocesses and load once per script, because SketchyBar
re-runs the plugins on every event.

Fonts are provisioned by `bootstrap/install/sketchybar.sh`:

- `sf-symbols` (Homebrew Cask)
- `font-sf-mono` and `font-sf-pro` (Homebrew Cask)
- `sketchybar-app-font` downloaded from
  `https://github.com/kvndrsslr/sketchybar-app-font`.

Runtime files are intentionally not tracked:

- Album covers fetched by the Spotify plugin are cached in `/tmp` only.
- No runtime sockets, logs, session data, or cache/state directories are included here.

`icon_map.sh` is sourced by bar scripts at runtime; it has no secrets and is safe to share publicly.
