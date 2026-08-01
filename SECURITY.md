# Security

## What this software is, in security terms

Shell scripts that write configuration files into your home directory and ask
Homebrew to install other people's software. There is no service, no network
listener, no account and no telemetry. The realistic risks are therefore about
what runs on your machine and what gets written over, not about a remote
attacker.

Three things are worth knowing before you run it.

**It installs software from third-party Homebrew taps.** AeroSpace comes from
`nikitabobko/tap`, SketchyBar and borders from `felixkratz/formulae`, Kaku from
`tw93/tap`. Homebrew 6 refuses to install from a tap you have not trusted, and
this repository deliberately does not trust them for you — the plan printed by
`--dry-run` names them, and `brew trust` is a decision you make. Trusting a tap
lets its maintainer's code run on your machine.

**Some modules need macOS permissions that are broad.** Accessibility lets a
program move any window. Input Monitoring lets it see keystrokes. Full Disk
Access, which the `notifications` module asks for, includes your notification
database. Every module states its permissions in `bootstrap/catalog.sh` and in
the plan `--dry-run` prints, and no module asks for a permission it does not
use. [docs/privacy.md](docs/privacy.md) says what each one reads and where it
writes.

**Config files under `~/.config` are read as data, but not all of them.**
`profile.conf`, `theme.conf`, `displays.conf`, `workspaces.conf` and
`app-routes.conf` are parsed: a value that looks like a command is treated as a
string. `colors.sh` and `bordersrc` are shell and are executed — they are
programs, and the files say so at the top. If you copy someone else's config,
that distinction is the one to check.

## Reporting a vulnerability

Open a [private security advisory][advisory]. If you would rather not use
GitHub, the email address on the commits in this repository works.

Please include what you ran, what happened, and what you expected. A reproducer
that fits in a shell snippet is worth more than a description.

There is no bounty, and no formal response window: this is one person's project.
Reports about the categories below will be answered, and anything credible will
be fixed before anything else in the queue.

[advisory]: https://github.com/aklmans/ai-first-dotfiles/security/advisories/new

## What counts

- A path where a config file's contents get executed when the documentation says
  they are read as data.
- A deploy that overwrites or deletes something without backing it up first,
  or that writes outside the paths its module declares.
- A script that follows a symlink at a target path instead of refusing it.
- A privilege or permission asked for that the module does not use.
- A shell injection reachable through a filename, a monitor name, an app name or
  anything else that arrives from outside the repository.

## What does not

- **Homebrew installing software.** That is the whole point of the tool. Which
  packages, from which taps, is a choice the plan shows you before it runs.
- **Broad macOS permissions being requested.** Accessibility is what a window
  manager needs. The bug would be asking for one nothing uses.
- **`colors.sh` or `bordersrc` executing.** They are shell by design and say so.
  A file this repository calls data executing *is* a bug — see above.
- **Running `./bootstrap/setup.sh` with a modified checkout.** If you can edit
  the scripts, you can already run anything.

## Supported versions

The `main` branch. This is a dotfiles repository, not a released product: there
are no version branches to backport to, and the fix for anything found here is
to pull and re-run the installer.
