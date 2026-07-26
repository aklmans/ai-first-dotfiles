# Troubleshooting

Ordered by how often it actually happens.

## "Everything installed and nothing works"

This is almost always a permission, not a bug. macOS grants nothing on your
behalf and the apps fail silently when they lack it.

| Symptom | Cause | Fix |
|---|---|---|
| Windows never tile or move | AeroSpace has no Accessibility permission | System Settings → Privacy & Security → Accessibility → enable **AeroSpace**, then restart it |
| No CapsLock behavior at all | Karabiner's driver extension was never approved | System Settings → General → Login Items & Extensions → Driver Extensions → enable **Karabiner-Elements**, restart when asked, then check Privacy & Security → Input Monitoring |
| CapsLock is installed but does nothing | The rules ship disabled on purpose | Karabiner-Elements → Complex Modifications → Add rule → **CapsLock AI Lite (ai-first-dotfiles)** → Enable All |
| AI hotkeys do nothing | Hammerspoon has no Accessibility permission | System Settings → Privacy & Security → Accessibility → enable **Hammerspoon**, then reload its config |
| Prompts render but the selection is always empty | Hammerspoon was denied Automation → System Events | System Settings → Privacy & Security → Automation → allow **Hammerspoon** to control **System Events** |
| Trackpad gestures do nothing | BetterTouchTool is in the `extras` profile and is not installed by `all` | `./bootstrap/setup.sh extras`, then grant it Accessibility |
| `Ctrl + ↑` / `Ctrl + ↓` do nothing | They route Mission Control and App Exposé through BetterTouchTool | `./bootstrap/setup.sh extras` |

Restart each app after granting a permission. macOS does not apply it to a
running process.

## "The shortcuts fight me"

`Ctrl + ←` / `Ctrl + →` are bound by macOS as **Move left/right a space** and
ship enabled. Turn them off under System Settings → Keyboard → Keyboard
Shortcuts… → Mission Control. Same panel for **Switch to Desktop N**, which
collides with `Ctrl + 1..9` when you keep more than one macOS Desktop.

Every CapsLock tap switches input source: macOS still has **Use the Caps Lock
key to switch to and from ABC** enabled under Keyboard → Input Sources → Edit…
Turn it off; Karabiner owns the whole key now.

## "It said it skipped something"

`N path(s) were left untouched` is not an error. The deploy engine refuses to
write through a symlink, because a symlink means another dotfiles manager (Stow,
chezmoi, your own script) owns that path. Nothing was overwritten, moved or
deleted.

To hand a path to this repo, move the link aside yourself, or re-run with
`--force` / `DOTFILES_FORCE=1`, which backs the link up before replacing it.

`Kept local change: <path>` is also not an error. The target differs from this
repo's copy, and this repo has not changed that file since it deployed it — so
the difference came from your machine and stays. `--force` overwrites it.

## Install-time failures

### `command not found: brew`

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Open a new shell so `brew` lands on `PATH`, then re-run the module.

### `This setup supports Apple Silicon only`

It does. The desktop layer hard-codes `/opt/homebrew`, so on an Intel Mac the
install would succeed and wire nothing up. `--dry-run` still previews.
`DOTFILES_SKIP_PREFLIGHT=1` bypasses the check if you know what you are taking on.

### `Permission denied` running an installer

```bash
chmod +x bootstrap/*.sh bootstrap/install/*.sh tests/smoke/*.sh
```

### One step failed and the run continued

That is deliberate. Every step's exit code is captured and the failures are
listed together at the end, so one brew hiccup does not hide the other fifteen
modules. Fix the cause and re-run the same profile — every step is idempotent.

## Module-level checks

### AeroSpace

```bash
brew services restart nikitabobko/tap/aerospace || true
open -a AeroSpace

# Does ~/.aerospace.toml still match displays.conf and workspaces.conf?
~/.config/aerospace/render-layout.sh --check

# Full report on the desk vs the config
~/.config/aerospace/doctor.sh
```

If workspaces land on the wrong monitor, that is `displays.conf`, not a bug.
`aerospace list-monitors` prints the exact names to put in it.

### SketchyBar / Borders

```bash
brew services restart sketchybar
brew services restart borders
zsh -n home/.config/sketchybar/sketchybarrc
./bootstrap/install/sketchybar.sh
```

The bar reads its fonts, height and colors from
`~/.config/sketchybar/theme.conf` only. Edit that file, restart the service.

### Karabiner

The tracked `karabiner.json` in this repo is a **reference copy** of the profile
these rules produce. It is deliberately never deployed — Karabiner reads *and
writes* that file, and overwriting it would replace every profile and device
override you have. What gets installed is the asset:

```bash
python3 -m json.tool ~/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json
```

If that parses and the rule still does not appear, the file is in the wrong
place: Karabiner only scans
`~/.config/karabiner/assets/complex_modifications/`. Re-run
`./bootstrap/install/karabiner.sh`.

What each rule does: `home/.config/karabiner/CapsLock-AI-Lite.md`.

### Hammerspoon

```bash
open -a Hammerspoon
lua -e "assert(loadfile('home/.hammerspoon/init.lua'))"
lua -e "assert(loadfile('home/.hammerspoon/ai_hotkeys.lua'))"
```

### AI Router

```bash
~/.config/ai-router/ai-router.sh doctor      # what it can and cannot reach
~/.config/ai-router/ai-router.sh index       # rebuild the prompt catalog
~/.config/ai-router/ai-router.sh export-snippets all
```

If the exported snippets drift from the prompts:

```bash
HOME="$PWD/home" bash home/.config/ai-router/tests/run.sh
bash tests/smoke/ai_router_exports_smoke.sh
```

### Terminal (Kaku / Warp / Yazi)

```bash
./bootstrap/install/yazi.sh     # re-run if a plugin install failed on the network
```

Restart Yazi to pick up rebuilt key mappings.

### mpv

ModernX draws with `material-design-iconic-font` glyphs. If icons are missing,
re-run `./bootstrap/install/mpv.sh` for a best-effort font install, or install a
Nerd/Material font yourself and reopen mpv.

## Still broken

1. Re-run the smoke suite and capture the output:

   ```bash
   for t in tests/smoke/*.sh; do echo "== $t"; bash "$t" || echo "FAILED"; done
   ```

2. Re-run the failing module installer on its own.
3. Check for local overrides shadowing the defaults: `~/.config/zsh/private.zsh`,
   `.local` files, anything under `~/.config/<module>/` you edited.
4. Open an issue with your macOS version, the module, and the output of
   `./bootstrap/setup.sh <module> --dry-run`. The
   [bug report template](https://github.com/aklmans/ai-first-dotfiles/issues/new/choose)
   asks for exactly that.
