# macOS defaults — examples only

**`bootstrap/setup.sh` never runs anything in this directory.** These scripts are
kept as a reference for `defaults write` tweaks used on the author's machine. Read
each one before running it, and run them individually:

```bash
bash examples/macos-defaults/finder.sh
```

Most take effect only after the affected app (Finder, Dock, Safari) is restarted,
and there is no rollback script — note the previous value with `defaults read`
first if you care about restoring it.

| Script | Touches |
|---|---|
| `access.sh` | Cursor size, crash reporter dialog, personalized-ad opt-out |
| `activity_monitor.sh` | Activity Monitor default view |
| `battery.sh` | Battery and power-management behaviour |
| `desktop.sh` | Desktop icon behaviour |
| `dock.sh` | Dock size, autohide, and contents — **`dock.sh` clears the existing Dock** |
| `finder.sh` | Finder view, extensions, path bar |
| `safari.sh` | Safari developer and privacy settings |
| `system.sh` | Assorted system-wide UI defaults |
| `trackpad.sh` | Trackpad tap-to-click and gestures |

Scripts that lowered system security (disabling Gatekeeper, download quarantine,
and disk-image verification) were removed from this repository rather than moved
here.
