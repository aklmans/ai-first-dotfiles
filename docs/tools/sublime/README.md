# Sublime Text

This repository only manages a small Sublime Text integration instead of taking over the full editor profile.

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
