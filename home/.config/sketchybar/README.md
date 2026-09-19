## SketchyBar Configuration

This directory contains a public, reusable SketchyBar setup and plugin layout.

Layout:

- `theme.conf` - fonts, sizes, geometry and colour roles. The one file to edit to restyle the bar.
- `colors.sh` - the palette the roles in `theme.conf` refer to.
- `icons.sh` - UI symbols. `plugins/icon_map.sh` - application aliases.
- `fonts/` - the matching bundled monochrome app font, manifest and licenses.
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
- `AI First App Icons` is bundled in `fonts/`, based on
  [sketchybar-app-font v2.0.89](https://github.com/kvndrsslr/sketchybar-app-font/releases/tag/v2.0.89)
  with additional monochrome glyphs. SketchyBar loads it into its own process;
  no font download/build or replacement in `~/Library/Fonts` is required.

App icon coverage includes ZCode/Preview, Kimi Code, Kimi, Surge, Loopback,
Qoder/CN IDE/Work aliases, WorkBuddy, TRAE/CN/SOLO/Work aliases, DoubaoWork, Cola
and Camtasia, plus 万兴图示/EdrawMax and 万兴脑图/EdrawMind/MindMaster.
Cola no longer borrows the unrelated Spark mail icon.
Ordinary Doubao uses a different glyph. Display names and common bundle IDs are
matched exactly, not guessed by substring. Unknown apps use `:default:`; Air's
old nonexistent `:junie:` mapping also now explicitly falls back to that symbol.

The shipped `SKETCHYBAR_FONT_APP` is `AI First App Icons`. A preserved private
theme naming the old stock `sketchybar-app-font` automatically resolves to the
bundled family without rewriting the theme; other custom families remain as set
and must provide compatible ligatures. The font and `icon_map.sh` must be
deployed together. After a font-content update, restart SketchyBar if the old
font remains cached; do not remove system fonts or clear system font caches.
Startup rejects a missing or checksum-mismatched bundled font before configuring
the bar, instead of silently showing empty glyphs after an incomplete copy.

See [font sources and rebuild instructions](../../../assets/app-icons/README.md)
in the repository. A deployed standalone copy does not include the build tools.

Runtime files are intentionally not tracked:

- Album covers fetched by the Spotify plugin are cached in `/tmp` only.
- No runtime sockets, logs, session data, or cache/state directories are included here.

`icon_map.sh` can be executed with one or more app names, or sourced silently to
use `__icon_map` and `icon_result`. It contains no private app inventory or secrets.
