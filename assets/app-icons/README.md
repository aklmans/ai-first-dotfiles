# Monochrome app icons

`home/.config/sketchybar/fonts/ai-first-app-icons.ttf` is a generated, copy-deployed
asset. It combines **sketchybar-app-font v2.0.89** with sixteen additional monochrome
glyphs. All app-name mappings must correspond to an actual nonempty ligature.
Neither installation nor bar startup downloads or builds this font.

The distinct `AI First App Icons` family is loaded using SketchyBar's
[`--load-font`](https://felixkratz.github.io/SketchyBar/setup) mechanism. The old
font in `~/Library/Fonts` is not replaced, removed or required. The font travels
with the bar's normal copy-deploy/update/rollback scope.

## Sources and attribution

- Base: [kvndrsslr/sketchybar-app-font v2.0.89](https://github.com/kvndrsslr/sketchybar-app-font/releases/tag/v2.0.89),
  CC0-1.0. Download URL and SHA-256 are pinned in `build.py` and the generated
  manifest. `licenses/CC0.txt` retains the license.
- Kimi, Qoder, TRAE, Doubao and Manus: monochrome paths from
  [LobeHub icons at a94750e3](https://github.com/lobehub/lobe-icons/tree/a94750e3f5f8fc33757b839d85030e742284e43a/src),
  specifically each brand's `components/Mono.tsx`. JSX was converted to SVG;
  Qoder's shading was flattened to a single-color silhouette. MIT notice is in
  `licenses/MIT-LobeHub.txt`.
- WorkBuddy: adapted from the [official website's SVG](https://download.codebuddy.ai/web/workbuddy/ea2a61614c71b7bed74ab35460e918796a083362/assets/logo.svg),
  with its background, clipping and color effects removed; retains the mascot
  outline and eyes. The SVG was linked by `workbuddy.ai` during this update.
- ZCode, Kimi Code, Surge, Loopback, DoubaoWork, Cola, Camtasia, CodexBar, EdrawMax and
  EdrawMind/MindMaster: small monochrome vector
  adaptations of the respective macOS app icons, redrawn for 16px use. They are
  not the original color assets and not official replacement artwork. Sources
  are the corresponding apps' packaged icons, inspected locally without reading
  any app/user data. ZCode Preview shares ZCode; TRAE SOLO/CN/Work aliases share
  TRAE. Kimi Code and DoubaoWork intentionally do not share Kimi/Doubao glyphs.
  EdrawMax and EdrawMind retain their distinct center marks without the shared
  Wondershare footer/background; their Chinese app names are also mapped.
  CodexBar retains its chevron and segmented usage bar. Manus and Manus Studio
  share the Manus mark. Craft and Xmind use existing base-font glyphs with exact
  app-name and bundle-ID mappings.

Application names and logos identify the corresponding products; trademark and
brand-art rights remain with their owners. The base font's CC0 and LobeHub's MIT
terms do not imply trademark permission for unrelated uses or apply to vendor
brand artwork. No screenshots, installed apps, or private app inventories are
bundled here.

## Rebuild (maintainers only)

Use a temporary virtual environment, not the system Python. Requirements are
only for building, not installing or running the bar:

```bash
python3 -m venv /path/to/temporary/venv
/path/to/temporary/venv/bin/pip install -r assets/app-icons/requirements.txt
curl --fail --location --output /path/to/temporary/upstream.ttf \
  https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.89/sketchybar-app-font.ttf
/path/to/temporary/venv/bin/python assets/app-icons/build.py \
  --base /path/to/temporary/upstream.ttf
```

`build.py` performs no network requests or font installation, rejects another
base hash, preserves existing glyphs, adds the SVG outlines/ligatures and writes
the font, licenses and manifest under `home/.config/sketchybar/fonts`. `--output`
allows a separate reproducibility check. Fixed timestamps and pinned tooling
make identical inputs reproduce the same font bytes in the verified environment.
Only filled paths/rectangles, matrix transforms and explicit white subtraction
are supported. Flatten strokes/effects before adding a new source.

Run:

```bash
bash tests/run-all.sh tests/smoke/app_icons_smoke.sh tests/smoke/sketchybar_smoke.sh
```

The tests use only Python's standard library. They verify input/artifact hashes,
read the TTF's cmap/GSUB/loca/glyf/hmtx tables, check every declared ligature has
an outline and advance, and exercise actual Bash mappings. They are not a
substitute for a native CoreText visual check. Update the font and manifest
together whenever a source, mapping, builder or pinned build requirement changes.
