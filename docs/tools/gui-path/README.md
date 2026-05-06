# GUI PATH Helper

macOS GUI apps launched from Dock, Spotlight, Finder, or login items often inherit a minimal `PATH` from `launchd` instead of the interactive shell environment.

This can break tools that shell out to Homebrew binaries. A common example is Sublime Text LSP packages failing to find `node` even though `node` works in Terminal.

## What It Installs

The module deploys:

```text
$HOME/Library/LaunchAgents/com.aklman.gui-path.plist
```

It sets the GUI launchd path to:

```text
/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

## Install

From the repo root:

```bash
./bootstrap/setup.sh gui-path
```

Or as part of the full setup:

```bash
./bootstrap/setup.sh all
```

Restart any already-running GUI apps after installing this module so they inherit the updated environment.

## Verify

```bash
launchctl print "gui/$(id -u)" | sed -n '/environment = {/,/}/p'
```

The output should include `/opt/homebrew/bin` in `PATH`.

For Sublime Text LSP-json, a successful runtime looks like:

```text
/opt/homebrew/bin/node .../LSP-json/.../jsonServerMain.js --stdio
```
