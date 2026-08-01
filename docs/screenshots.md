# Screenshots

This repository includes public screenshots that show the main desktop, workspace, terminal, and AI workflow surfaces.

## Purpose

Screenshots help new users verify:

- workspace layout behavior
- desktop status bar and borders
- prompt and chooser UX
- AI Router exports/import flows

## Included screenshot set

Use public demo windows and avoid any real names, project paths, logs, tickets, or emails.

| File | Purpose | Referenced from |
|---|---|---|
| [`aerospace-tiling-layout.png`](../assets/screenshots/aerospace-tiling-layout.png) | Multi-window AeroSpace tiling with the workspace bar. | `README.md` (hero), `docs/tools/aerospace/README.md` |
| [`desktop-overview.png`](../assets/screenshots/desktop-overview.png) | Full desktop with workspace bar, no windows open. | this page |
| [`sketchybar-workspace-bar.png`](../assets/screenshots/sketchybar-workspace-bar.png) | Top bar showing workspace indicators and app icons. | `docs/tools/sketchybar/README.md` |
| [`capslock-chooser.png`](../assets/screenshots/capslock-chooser.png) | AI Router prompt chooser. | `docs/tools/ai-router/README.md` |
| [`agent-chooser.png`](../assets/screenshots/agent-chooser.png) | Long-running coding agent chooser. | `docs/tools/hammerspoon/README.md` |
| [`starship-prompt.png`](../assets/screenshots/starship-prompt.png) | Shell prompt with path and git context. | `docs/tools/zsh-starship/README.md` |
| [`kaku-warp-terminal.png`](../assets/screenshots/kaku-warp-terminal.png) | Terminal workflow with Kaku/Warp-oriented configuration. | `docs/tools/terminal/README.md` |
| [`raycast-import.png`](../assets/screenshots/raycast-import.png) | Raycast snippet import flow for AI Router exports. | `docs/tools/ai-router/README.md` |
| [`bettertouchtool-gestures.png`](../assets/screenshots/bettertouchtool-gestures.png) | Trackpad gesture configuration for workspace movement. | `docs/tools/bettertouchtool/README.md` |
| [`karabiner-profile.png`](../assets/screenshots/karabiner-profile.png) | `CapsLock AI Lite` Karabiner profile. | `docs/tools/karabiner/README.md` |

## Known-stale shots

- `capslock-chooser.png` still shows the prompt catalog with Chinese
  descriptions. The default prompt set is English now; the Chinese set moved to
  `home/.config/ai-router/prompts/zh/`. Recapture before relying on it.
- `karabiner-profile.png` shows the old `CapsLock AI Lite` *profile*. The install
  now ships a complex-modification rule you enable yourself, so the screen a new
  user sees is Complex Modifications → Add rule, not the profile list.

## Gallery

### Desktop overview

![Desktop overview with SketchyBar and AeroSpace workspaces](../assets/screenshots/desktop-overview.png)

### SketchyBar workspace bar

![SketchyBar workspace bar](../assets/screenshots/sketchybar-workspace-bar.png)

### AeroSpace tiling layout

![AeroSpace tiling layout](../assets/screenshots/aerospace-tiling-layout.png)

### AI Router chooser

![AI Router CapsLock chooser](../assets/screenshots/capslock-chooser.png)

### Coding agent chooser

![Coding agent chooser](../assets/screenshots/agent-chooser.png)

### Starship prompt

![Starship prompt](../assets/screenshots/starship-prompt.png)

### Terminal workflow

![Kaku and Warp terminal workflow](../assets/screenshots/kaku-warp-terminal.png)

### Raycast snippet import

![Raycast snippet import](../assets/screenshots/raycast-import.png)

### BetterTouchTool gestures

![BetterTouchTool workspace gestures](../assets/screenshots/bettertouchtool-gestures.png)

### Karabiner profile

![Karabiner CapsLock AI Lite profile](../assets/screenshots/karabiner-profile.png)

## Capture briefs

Four things are missing or stale. Each brief below is meant to be followed
without deciding anything: the shot list, the exact keys, and the commands.

### Before any of them

1. **Pick one display and record only that.** A 4K panel at 2x scaling records
   at 3840x2160, which is four times the pixels anyone will look at. Record a
   region instead — the commands below all take one.
2. **Close what does not belong on the internet.** Mail, Messages, any browser
   with tabs, anything with a customer's name in the title bar. Quit them rather
   than hiding them: AeroSpace's workspace row shows an icon per running app.
3. **Turn off notifications.** System Settings → Notifications → Do Not Disturb,
   or `Focus` in the menu bar. A banner mid-recording means starting over.
4. **Use demo content.** `demo-workspace`, `sample-repo`, placeholder text. The
   sanitization rules below are the full list.
5. **Check the desktop wallpaper.** It is in every frame.

### 1. The hero GIF — 15 seconds, README first screen

This is the one that has to earn a stranger's attention, and the thing worth
showing is not tiling — everybody has seen tiling. It is that switching away and
back costs nothing: no animation to sit through, no window to find again, the
cursor still where it was.

| Time | What you do | What has to be visible |
|---|---|---|
| 0:00–0:02 | Nothing. Hold still on workspace 1 with two windows tiled — an editor with a visible cursor in the middle of a line, and anything beside it | The SketchyBar row across the top, `1` highlighted |
| 0:02–0:03 | Press `Ctrl+5` | The row's highlight jumps to `5`. Do not move the mouse |
| 0:03–0:08 | On workspace 5, type a short reply in a chat-shaped window and send it | That the workspace changed completely, not that a window moved |
| 0:08–0:09 | Press `Ctrl+1` | Highlight jumps back to `1` |
| 0:09–0:12 | Type three or four characters where the cursor was | **The cursor is exactly where you left it.** This is the whole point of the clip |
| 0:12–0:15 | Hold still | — |

Record it:

```bash
mkdir -p ~/Desktop/gif && cd ~/Desktop/gif
screencapture -v -R 0,0,1920,1080 demo.mov
```

`-R x,y,w,h` is the region in points. Recording stops on `Ctrl+C` in that
terminal — so start the recording, switch to the desk, do the fifteen seconds,
then come back. Trim the ends afterwards rather than trying to be exact:

```bash
ffmpeg -ss 3 -t 15 -i demo.mov -c copy trimmed.mov
```

`-ss 3` drops the first three seconds — adjust until it starts on the still
frame. Then to GIF, palette-generated so the colours survive:

```bash
ffmpeg -i trimmed.mov -vf "fps=15,scale=1000:-1:flags=lanczos,palettegen" -y /tmp/pal.png
ffmpeg -i trimmed.mov -i /tmp/pal.png \
  -lavfi "fps=15,scale=1000:-1:flags=lanczos [x]; [x][1:v] paletteuse" \
  -y ../ai-first-dotfile/assets/screenshots/workspace-switch.gif
```

Check the size — GitHub will serve anything but a reader on a phone will not
wait for it:

```bash
ls -lh assets/screenshots/workspace-switch.gif   # aim for under 5 MB
```

If it is too big, in this order: shorten the clip, drop to `fps=12`, then
`scale=800`. If it is still too big, `brew install gifski` and use that instead
of the second ffmpeg command — it is markedly better at this:

```bash
mkdir -p /tmp/frames
ffmpeg -i trimmed.mov -vf "fps=15,scale=1000:-1:flags=lanczos" /tmp/frames/f%04d.png
gifski -o assets/screenshots/workspace-switch.gif --fps 15 --quality 90 /tmp/frames/f*.png
```

Then replace the `<!-- GIF slot -->` comment near the top of `README.md` with:

```html
<img src="assets/screenshots/workspace-switch.gif" alt="Pressing Ctrl+5 switches to another workspace, a message is answered there, and Ctrl+1 returns to the first workspace with the text cursor still where it was" width="100%">
```

### 2. `capslock-chooser.png` — stale, re-shoot

The current file shows the prompt catalog with Chinese descriptions. The
shipped set is English; the Chinese set moved to
`home/.config/ai-router/prompts/zh/`.

1. Select a sentence of placeholder text anywhere.
2. Press the CapsLock chooser binding (`docs/shortcuts.md` has it for your
   profile).
3. Capture just the chooser window, not the whole screen:

```bash
screencapture -w -o ~/Desktop/capslock-chooser.png
```

`-w` captures a window, `-o` leaves off the drop shadow. Click the chooser when
the cursor turns into a camera.

The prompt list has to be the English one. If it is not, the deployed router is
older than the repository — re-run `./bootstrap/setup.sh ai --deploy-only` first.

### 3. `karabiner-profile.png` — stale, re-shoot

The current file shows a Karabiner *profile*. The install ships a
complex-modification rule you enable yourself, so the screen a new user actually
meets is a different one.

Capture **Karabiner-Elements → Complex Modifications → Add rule**, with the
`CapsLock AI Lite` rules from this repository visible in the list.

```bash
screencapture -w -o ~/Desktop/karabiner-rules.png
```

Save it as `assets/screenshots/karabiner-rules.png` — a new name, because it is
a different screen — and update the two references to `karabiner-profile.png`
in this file and in `docs/tools/karabiner/README.md`, then delete the old file.

### 4. Social preview card — 1280x640

GitHub shows this whenever a link to the repository is posted anywhere. There is
no such image yet, so those links currently render as a grey box with the repo
name.

Nothing here is a screenshot: it is a composed card. The simplest version that
works is a crop of the desk with the title over it.

1. Set up the desk the way the hero shot has it — bar visible, two windows
   tiled, no personal content.
2. `Cmd+Shift+4`, then Space, then click the screen to capture it whole.
3. Crop to exactly **1280x640** — Preview → Tools → Adjust Size, or:

```bash
sips -c 640 1280 ~/Desktop/social.png --out assets/screenshots/social-preview.png
```

`sips -c` crops from the centre, which is usually where the interesting part
is not — check the result and re-crop from Preview if the bar got cut off.

4. Upload it at **Settings → General → Social preview** in the repository. It is
   not committed by GitHub automatically, so commit the file as well.

Keep the important content in the middle: link previews on some sites crop the
edges.

## Screenshot sanitization rules

When you create screenshots for this repository:

- Remove real chats, URLs, project names, ticket IDs, and client/company identifiers.
- Do not capture notifications with personally identifying accounts or messages.
- Do not include secrets, API keys, token values, cookies, `.bash_history`, shell history, or browser login hints.
- Use demo project names such as `demo-workspace`, `sample-repo`, and placeholder text.
- Avoid capturing machine hostnames if they reveal an internal domain.

If a file currently contains sensitive content:

- regenerate with demo content
- crop and blur all sensitive regions
- or replace with a `TODO:` placeholder entry instead of uploading.

## Asset placement

- `assets/screenshots/README.md`
- `assets/screenshots/*.png`
