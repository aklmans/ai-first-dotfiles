# How this compares to yabai, Amethyst and Rectangle

The short version: those are window managers. This is not one.

This repository configures [AeroSpace][aerospace] and the things that have to
agree with it — a status bar, a keyboard layer, a few automation scripts, a
shell. If you are choosing a window manager, the comparison you want is
AeroSpace against the others, and it is in the first table. If you have already
chosen one, the second table is the one that says whether this is of any use to
you.

## Choosing a window manager

| | AeroSpace | yabai | Amethyst | Rectangle |
|---|---|---|---|---|
| What it does | i3-style tiling with its own workspaces | BSP tiling on macOS Spaces | Automatic tiling with preset layouts | Snapping windows to halves and quarters |
| Needs SIP changed | No | Partially, for the scripting addition — space manipulation and some window operations need it | No | No |
| Workspaces | Its own, independent of macOS Spaces | macOS Spaces | macOS Spaces | Not a concept |
| Keyboard | Built in | Usually paired with `skhd` | Built in | Built in |
| Configuration | One TOML file | A shell script | A GUI, plus a config file | A GUI |
| Automatic? | Yes, tiles as windows appear | Yes | Yes | No — you press a key per window |
| Written in | Swift | C | Swift | Swift |

Rectangle is on that list because it is what most people actually have, and it
solves a different problem: it does not decide where a new window goes, it moves
the one you are looking at when you ask. If that is all you want, tiling is a
large change to make for it.

The reason this repository builds on AeroSpace is the SIP row. Everything here
runs on a stock macOS with System Integrity Protection on. That is a constraint,
not a verdict: yabai can do things AeroSpace cannot, and the price is a boot
argument.

## Once you have one

| | This repository | Rolling your own |
|---|---|---|
| Window manager | AeroSpace, configured | Yours |
| Status bar | SketchyBar, with the workspace list read from AeroSpace rather than typed twice | Usually typed twice |
| Keyboard layer | A Karabiner complex-modification you enable yourself; `karabiner.json` is never written | Yours |
| Multi-display | Workspaces carry a role — main, side, stage — and roles resolve to whichever monitors are connected now | Monitor names in a config file |
| Existing dotfiles | Copied in file by file, backed up before replacement, a symlinked path refused rather than written through | However careful you are |
| Removal | `uninstall.sh` removes only files byte-identical to what it shipped | However careful you were |

That fourth row is the one worth reading twice if you already have a setup you
like. [docs/coexisting.md](coexisting.md) is the whole of it: four rules, and how
to check each one before you install rather than after.

## When this is the wrong thing to install

- **You want a window manager and nothing else.** Install AeroSpace. It is one
  `brew install` and one config file, and this repository would be sixteen
  modules you did not ask for.
- **You are on an Intel Mac.** The desktop layer names the Apple Silicon
  Homebrew prefix directly, in dozens of places across AeroSpace's config,
  Hammerspoon's module path and the SketchyBar plugins. Intel Homebrew lives
  somewhere else, so the install would succeed, report nothing, and leave a
  desktop where nothing is wired to anything. The installer refuses instead.
- **You want macOS Spaces.** AeroSpace emulates its own workspaces and does not
  drive Mission Control. If Spaces and their gestures are load-bearing for you,
  yabai is the closer fit.
- **You want a GUI.** There isn't one. Every choice is a file or a flag.

## What is actually different here

Not the window manager — that is AeroSpace's work. Three things:

**The plan comes before the install.** `./bootstrap/setup.sh <module> --dry-run`
prints every package, every tap, every path under `$HOME` it would write, and
the macOS permissions each module will ask for. Nothing is installed until you
run it again without the flag.

**It is not all-or-nothing.** Sixteen modules, each named for an outcome rather
than for the software behind it. `workspace` without `bar`, `bar` without
`capslock`, the shell layer without any of it.

**It is built to lose gracefully.** The deploy engine copies rather than
symlinks, backs up before it replaces, keeps a file it did not write, refuses a
path another dotfiles manager owns, and reports orphans rather than deleting
them. Those four rules are what the whole thing is for; the window management is
downstream of them.

[aerospace]: https://github.com/nikitabobko/AeroSpace
