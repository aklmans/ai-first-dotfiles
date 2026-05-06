# Sublime Text

This repository only manages small Sublime Text integrations instead of taking over the full editor profile.

## GUI PATH

Sublime Text plugins can run with a minimal macOS GUI `PATH` when the editor is launched from Dock, Spotlight, Finder, or login restoration. That can break packages such as `LSP-json`, which need to resolve Homebrew `node`.

The module deploys a tiny User plugin:

```text
$HOME/Library/Application Support/Sublime Text/Packages/User/gui_path.py
```

It prepends these paths inside Sublime's Python plugin host:

```text
/opt/homebrew/bin
/opt/homebrew/sbin
/usr/local/bin
```

This is intentionally scoped to Sublime and does not modify package source files.

## Terminal Package

The Sublime `Terminal` package is configured to open Warp at the current file or project directory:

```json
{
  "terminal": "/usr/bin/open",
  "parameters": ["-a", "/Applications/Warp.app", "%CWD%"]
}
```

This keeps the behavior independent from the macOS default Terminal app.

## Install

From the repo root:

```bash
./bootstrap/setup.sh sublime
```

Or as part of the full setup:

```bash
./bootstrap/setup.sh all
```

The module deploys:

```text
$HOME/Library/Application Support/Sublime Text/Packages/User/gui_path.py
$HOME/Library/Application Support/Sublime Text/Packages/User/Terminal.sublime-settings
```

It does not deploy `Default (OSX).sublime-keymap`, so existing personal Sublime shortcuts are left alone.

## Local Key Binding Note

If a local key binding passes custom terminal parameters, remove those parameters or make them match the Warp setting above. For example:

```json
{
  "keys": ["ctrl+alt+t"],
  "command": "open_terminal"
}
```

## AI-First Key Bindings

The module also deploys:

```text
$HOME/Library/Application Support/Sublime Text/Packages/User/Default (OSX).sublime-keymap
```

| Shortcut | Action |
|---|---|
| `Cmd + B` | Toggle sidebar |
| `Cmd + 1` | Focus sidebar |
| `Cmd + 2` | Open current file/project directory in Warp |
| `Cmd + 3` | Find in files |
| `Cmd + E` | Reveal current file in sidebar |
| `Cmd + Shift + E` | Reveal current file in Finder |
| `Cmd + Shift + C` | Copy current file path |

Sublime exposes only index-based commands for Open Recent, such as `open_recent_file` with a fixed index. This setup does not bind Open Recent because there is no built-in command for showing the full Open Recent menu as a chooser.
