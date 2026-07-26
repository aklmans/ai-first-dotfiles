# Karabiner CapsLock AI Lite

A `CapsLock`-based command layer for Karabiner-Elements: tap for `Escape`, hold for
Hyper, and a small, predictable set of navigation, editing and AI-entry chords on top.

![Karabiner CapsLock AI Lite profile](../../../assets/screenshots/karabiner-profile.png)

## How it is installed, and why that matters

Karabiner-Elements is a keyboard driver, and `~/.config/karabiner/karabiner.json` is
its live state: every profile, every per-device override and every rule you enabled in
the GUI lives in that one file, which the app reads *and rewrites*. Copying another
person's version over it does not merge anything. It replaces your keyboard
configuration wholesale.

So this module never writes `karabiner.json`. It deploys exactly one file:

```text
~/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json
```

Karabiner scans that directory and lists whatever it finds under
**Complex Modifications -> Add rule**. Dropping a file there adds an option. It changes
no active mapping, touches no profile you already have, and is undone by removing the
rule again.

## Installed files

- `home/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json` — deployed
- `home/.config/karabiner/karabiner.json` — reference only, **not deployed**
- `home/.config/karabiner/CapsLock-AI-Lite.md` — the full mapping table
- `bootstrap/install/karabiner.sh`

The reference `karabiner.json` shows the profile these rules produce. It carries no
device identifiers, so nothing in it is bound to one particular keyboard. Read it, or
copy pieces of it by hand; do not drop it on top of your own.

## Install

```bash
./bootstrap/install/karabiner.sh
```

Then enable the rules yourself:

```text
Karabiner-Elements -> Complex Modifications -> Add rule
-> "CapsLock AI Lite (ai-first-dotfiles)" -> Enable All
```

Nothing enables them for you. Enabling a rule rewrites the profile Karabiner is
currently running, which is a decision that belongs to whoever owns the keyboard.

Enable the groups one at a time if you want to try them: `CapsLock Hyper` is the only
one the others depend on.

## What it provides

Seven rule groups, 52 mappings in total:

| Rule group | What it does |
|---|---|
| `CapsLock Hyper` | `CapsLock` tap -> `Esc`, hold -> `Right Cmd + Ctrl + Opt + Shift` |
| `Navigation` | Vim-style arrows, word motion and selection on the Hyper layer |
| `Deletion` | Character, word and line deletion on the Hyper layer |
| `AI global shortcuts` | Stable `Ctrl + Opt + Cmd + Shift + <key>` chords for external tools |
| `App entry shortcuts` | The same chord shape, reserved for app entry points |
| `Direct launch shortcuts` | `Hyper + Ctrl + <key>` opens a terminal, IDE or AI client |
| `Screenshot and OCR launchers` | Screenshot, OCR and beautify entry points |

The AI and app-entry groups deliberately emit chords rather than doing the work
themselves, so Hammerspoon, Raycast, Keyboard Maestro or anything else can pick them up.
See `home/.config/karabiner/CapsLock-AI-Lite.md` for every mapping and the suggested
bindings, and the [Shortcut Reference](../../shortcuts.md) for the public table.

`Direct launch shortcuts` is the one group with machine-specific content: it opens apps
by bundle id (Warp, IntelliJ IDEA, GoLand, the Codex and ChatGPT clients). Edit or skip
that group if you do not use those.

## Uninstall

Remove the rule in **Complex Modifications**, then delete the asset:

```bash
rm ~/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json
```

`./bootstrap/uninstall.sh` does the file half of that for you. Removing the rule from
the running profile is still a GUI action, for the same reason enabling it is.

## Validation

```bash
python3 -m json.tool home/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json
python3 -m json.tool home/.config/karabiner/karabiner.json
```

Karabiner refuses to list a rule file it cannot parse, so an asset that survives
`json.tool` and still does not appear in **Add rule** is a schema problem rather than a
syntax one. `Karabiner-EventViewer` shows what the driver actually receives.

## Notes

- Legacy mouse-key, multi-clipboard, window-management and function-key layers are
  intentionally not part of this bundle.
- `home/.config/karabiner/karabiner.json.backup-*` is local only and is not tracked.
