# GUI PATH Helper

macOS GUI apps launched from Dock, Spotlight, Finder, or login items often inherit a minimal `PATH` from `launchd` instead of the interactive shell environment.

This can break tools that shell out to Homebrew binaries. A common example is Sublime Text LSP packages failing to find `node` even though `node` works in Terminal.

## What It Installs

The module deploys:

```text
$HOME/Library/LaunchAgents/com.ai-first-dotfiles.gui-path.plist
```

At login the agent **prepends** Homebrew to the GUI session `PATH`:

```text
/opt/homebrew/bin:/opt/homebrew/sbin:<whatever the session already had>
```

It does not replace the session `PATH`. `launchctl setenv PATH <value>` has no append
form, so a naive version of this agent wipes any other entry — a Nix profile,
`~/.local/bin`, a second package manager — that something else had put there. The agent
also exits early when Homebrew is already on the `PATH`, so re-running it is a no-op
rather than a way to stack duplicate entries.

Installing also applies the same change to the session that is running right now, so
apps started today pick it up without a logout.

The `/opt/homebrew` prefix is the Apple Silicon location. `bootstrap/setup.sh` refuses to
install on Intel Macs, so it is correct by construction on every machine this repo
supports.

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
launchctl getenv PATH
```

The output should start with `/opt/homebrew/bin`.

For Sublime Text LSP-json, a successful runtime looks like:

```text
/opt/homebrew/bin/node .../LSP-json/.../jsonServerMain.js --stdio
```

## Uninstall

```bash
./bootstrap/uninstall.sh --system-only --apply
```

That boots the agent out and runs `launchctl unsetenv PATH`. Log out and back in to be
sure the session picked up the original value.
