# Coexisting with dotfiles you already have

The usual reason not to try someone else's dotfiles is that they arrive as a
`rm -rf` with better manners. This page is what happens here instead, and how to
check it before you believe it.

Everything below is enforced by [`deploy_engine_smoke.sh`](../tests/smoke/deploy_engine_smoke.sh),
which is 103 checks against a throwaway `$HOME`.

## The four rules

**1. A directory is deployed file by file.** Your own prompts, SketchyBar items
and router state are files this repo does not ship, and it never removes them —
the target directory is not moved aside and re-created. That was the original
bug this engine was written to fix.

**2. A file you changed is not overwritten.** Each deploy records a checksum of
the repo copy it wrote. Next time, a target that differs is compared against
that record: if the repo copy has not moved since, the difference came from you
and it stays.

```
Kept local change: ~/.config/aerospace/app-routes.conf (this repo has not
changed it since deploying it; --force overwrites)
```

**3. Symlinks are never followed or replaced.** A symlink means Stow, chezmoi or
your own script owns that path. Deploying through it would silently cut the
link, so it is refused, the run continues, and the skipped paths are listed at
the end. That run exits 3 — “nothing was overwritten, nothing is broken” — not 1.

**4. Whatever is replaced is moved aside first, and recorded.** The backup goes
next to the original as `<name>.backup_<timestamp>`, and a row goes into
`~/.local/state/ai-first-dotfiles/backups.tsv`. If a file cannot be moved aside,
it is not replaced at all — the deploy skips it rather than writing without a
backup.

## Check it yourself before you install

The preview writes nothing and needs no Homebrew:

```bash
./bootstrap/setup.sh minimal --dry-run
```

Every path it would touch is listed, with `(new)`, `(exists; ... backed up
first)` or `(symlink; would be left untouched)` next to it. If your files are
symlinks, you will see that here, before anything runs.

To be certain rather than convinced, install into a fake home first:

```bash
HOME=/tmp/dotfiles-trial ./bootstrap/setup.sh minimal --deploy-only
find /tmp/dotfiles-trial -type f | head -40
rm -rf /tmp/dotfiles-trial
```

`--deploy-only` installs nothing, starts nothing and changes no macOS setting.

## If you use Stow, chezmoi or your own repo

Take the modules whose paths you do not already manage. The catalog is
independent outcomes, not a bundle:

```bash
./bootstrap/setup.sh workspace          # only ~/.aerospace.toml and ~/.config/aerospace
./bootstrap/setup.sh capslock           # only the Karabiner rule asset
```

Paths that collide will be skipped and named. Nothing forces you to resolve them
— a partial install is a supported state, and `./bootstrap/setup.sh doctor` will
tell you what is and is not in place.

The one module that takes over something structural is `shell`: it repoints
`~/.zshenv` at this repo's `ZDOTDIR`. It is never part of `minimal` or
`developer`, and it is the module to leave out if you have a shell setup you
like.

## Upgrading a checkout you installed earlier

Re-running the same preset is the update path, and it keeps your edits by rule 2
above. Two things to know:

**`~/.aerospace.toml` is generated between markers.** `render-layout.sh` rewrites
only the blocks between its `>>> generated` / `<<< generated` comments and copies
everything else through, so your own keybindings and comments survive.

An `~/.aerospace.toml` from before those markers existed has nowhere to write, and
`render-layout.sh` stops rather than guessing where the generated block belongs.
Running the module is not how you meet that: `setup.sh workspace` deploys the
shipped file — backing yours up first — and renders into that, so the upgrade goes
through without ever reaching the refusal. You only see it by running
`render-layout.sh` directly against an old file.

Either way your previous file is kept beside it, twice: `.backup_<stamp>` from the
deploy and `.bak-<stamp>-render-layout` from the renderer. Copy your own sections
back in from the first one.

**Files this repo used to ship and no longer does are reported, not deleted.**
A deploy that finds them prints them once, and leaves them where they are. That
is the deliberate asymmetry: this engine cannot tell an upstream deletion from a
file you wrote next to ours, and guessing wrong in that direction is exactly the
data loss it exists to prevent.

## Getting out

```bash
./bootstrap/uninstall.sh            # prints the plan, changes nothing
./bootstrap/uninstall.sh --apply
```

It replays the ledger newest-first. A file byte-identical to the copy this repo
shipped is removed; anything you changed is moved aside rather than deleted;
symlinks and non-empty directories are never touched. Homebrew packages are left
alone on purpose — you may have wanted `jq` anyway.

## What this does not protect

- **macOS permissions.** Accessibility, Input Monitoring and Full Disk Access are
  granted by you in System Settings and are not restored by anything here.
- **Homebrew state.** Taps added stay added; packages installed stay installed.
- **Anything outside `$HOME`.** The deploy engine only writes below your home
  directory, which is also why a symlinked home directory does not trip it.
