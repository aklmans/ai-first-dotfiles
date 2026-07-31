# BetterTouchTool Gestures

`BetterTouchTool` drives the trackpad gestures that complement AeroSpace
workspace movement.

> **It is never implied by a neutral preset.** BTT is free for 45 days and paid
> after that, so it is the explicit `gestures` module:
> `./bootstrap/setup.sh gestures`.
>
> Two keyboard shortcuts depend on it as well:
> `home/.config/aerospace/macos-control.sh` routes `Ctrl + ↑` (Mission Control)
> and `Ctrl + ↓` (App Exposé) through BTT's `trigger_action` API. Without BTT
> installed and running, those two keys silently do nothing.

![BetterTouchTool workspace gestures](../../../assets/screenshots/bettertouchtool-gestures.png)

## Installed files

- `home/.config/bettertouchtool/aerospace-gestures.sh`
- `home/.config/bettertouchtool/README.md`
- `bootstrap/install/bettertouchtool.sh`

## Install

```bash
./bootstrap/setup.sh gestures                # BetterTouchTool only
./bootstrap/install/bettertouchtool.sh       # or this module alone
```

The installer copies the tracked gesture preset script but does not start BetterTouchTool by default.
This keeps the base setup stable on multi-display systems where BTT can occasionally hold stale mouse/drag state after display changes.

To start BetterTouchTool and apply the gesture preset explicitly:

```bash
./bootstrap/install/bettertouchtool.sh --deploy-only --start
```

To stop BetterTouchTool during troubleshooting:

```bash
osascript -e 'tell application "BetterTouchTool" to quit'
```

## Gesture behavior

- 3/4-finger left and right gestures move to previous/next AeroSpace workspace groups.
- 3/4-finger up opens Mission Control.
- 3/4-finger down opens App Expose.
- The tracked configuration intentionally does not include private device IDs or account tokens.

Full shortcut map: [Shortcut Reference](../../shortcuts.md).

## What is not tracked

- BetterTouchTool full application DB or cloud state is intentionally excluded.
- You only keep portable script/gesture presets in this repository.

## Permissions

Grant Accessibility permissions for global gesture handlers.

If gestures do not trigger:

1. Restart BetterTouchTool.
2. Check macOS permissions.
3. Reload the preset script and reapply.

If mouse selection or dragging stops working, quit BetterTouchTool first.
The tracked Hammerspoon config does not listen to mouse down/drag/up events, so BTT is the higher-risk event layer for that symptom.
