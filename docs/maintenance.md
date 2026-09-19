# Update, recover, and move your private configuration

Installation, module selection, feature enablement, file updates and desktop
activation are separate decisions. All maintenance commands below preview by
default. They neither install packages nor contact providers.
Python 3.9+ and Git are required; the TOML reader is vendored for offline use.

## Adopt an existing installation

```bash
./bootstrap/setup.sh select
./bootstrap/setup.sh select workspace bar recording --apply
./bootstrap/setup.sh update
./bootstrap/setup.sh update --apply
```

New successful public module/preset installs record `selection.json`. A legacy
public preset produces a **candidate**, not a silent migration. A private or
unknown profile requires explicit module names. Existing app/config files are
not evidence that you selected every module. Dependencies are included; removing
a module from selection stops future updates, not a running feature or app.

`update` copies only the selected modules' declared assets and shared preference
reader, then renders the complete workspace/shortcut/app-rule candidate. It uses
repository implementation with local data, not an old installed renderer.
An invalid render refuses **before any implementation copy**. Process-only
`AI_FIRST_*`/`AEROSPACE_*` overrides are not persistent maintenance intent.

Existing `.conf`, `.toml`, `.json`, YAML, plist, Sublime settings/keymap files,
`.zshenv`, `.ideavimrc`, Kaku/Yazi preference Lua, SketchyBar colors and Borders
preferences are kept. Existing `.aerospace.toml` is a render template: managed
blocks change; other content stays. Missing preference files are seeded. Other
implementation files follow copy deployment's local/upstream conflict checks.
Unknown pre-existing implementation files may be backed up and replaced on their
first adoption; read the path plan before applying. Nothing is symlink-deployed.

This is not a package updater, preference-default migration, shell takeover,
AI-router prompt-index rebuild, or automatic removal of obsolete files.
`deploy --all --dry-run` is the explicit broad compatibility path, **not** a
preference-preserving update. Independently invoked installers keep their
installation behavior; use `--deploy-only` to suppress package/system actions.

For installed software, use the separate read-only `setup.sh software plan` /
`software check` workflow. See [software ownership](software-maintenance.md):
private install lists, package owners and vendor updaters are not module selection.

## Adding and enabling a module

```bash
./bootstrap/setup.sh recording --dry-run
./bootstrap/setup.sh recording --deploy-only
# Review the proposed overlay before explicitly accepting its defaults:
./bootstrap/setup.sh recording --deploy-only --accept-preferences
```

On an existing configuration, installing a module preserves your preferences by
default. `--accept-preferences` opts into the displayed overlay; local-edit
protection still applies. Recording does **not** choose a routing pack, change the
stage workspace, or turn on unrelated hotkeys, notifications or window automation.
Initial module-only composition receives a neutral base. Choosing a named preset
explicitly is a preference change; do not reapply it as a routine update.

`setup.sh doctor` separates selection, installed assets/tools, configured feature
flags, static config checks and **unverified runtime**. Unselected modules are not
reported missing. A closed feature can still have missing assets. Shell/JSON
checks are partial for most modules; workspace validation includes complete TOML
syntax and project workspace/route invariants, not every version-specific
AeroSpace command or macOS permission.

## Activation and recovery

```bash
./bootstrap/setup.sh update --apply --activate  # explicitly affects the desktop
./bootstrap/setup.sh operations
./bootstrap/setup.sh rollback OPERATION_ID
./bootstrap/setup.sh rollback OPERATION_ID --apply
./bootstrap/uninstall.sh                       # preview recorded changes only
./bootstrap/uninstall.sh --apply
```

The default update does not use desktop IPC. Explicit activation asks AeroSpace
to validate/reload and, when available, Hammerspoon to reload. An activation
failure exits nonzero and records `activation-failed`; it does not claim the file
deployment failed or undo an earlier reload.

New **select, update and import** operations record their plan, SHA-256 before/
after states, private before images, implementation revision, failures and
activation result under `~/.local/state/ai-first-dotfiles/operations/` (or
`$XDG_STATE_HOME/ai-first-dotfiles/operations/`). Successful setup records a
selection operation; its installation file/package steps are still legacy-ledger
operations. Advisor edits and standalone render/route commands retain their own
backups, not this operation history.

Rollback restores **one** operation. Roll back newer overlapping operations
first. Uninstall preflights the entire recorded chain, then rolls it back newest
first. Both refuse user-edit, linked-path and corrupt-image conflicts before
restoring files. They retain recovery images and nonempty directories. Neither
reloads services. Adjacent legacy/renderer backups and history remain; removing
them is a separate manual retention decision.

Legacy `backups.tsv` is a read-only recovery reference, not proof of the earliest
machine state. Legacy-only `uninstall --apply` refuses. No original ownership
record means **no** automatic service stop, package uninstall, defaults deletion,
permission revocation or GUI PATH reversal. Review old backups manually.

There is no global transaction across files or services. Writers share a lock;
individual replacements are atomic, and a recorded partial failure can be
retried/recovered after review. An uncooperative external editor can still race a
write; this is not a hostile-process boundary. Abrupt power loss/SIGKILL can leave
an incomplete record or lock: do not delete a lock without checking its owner,
and do not guess missing `after` state during automatic recovery.

## Private intent export and restore rehearsal

```bash
./bootstrap/setup.sh export /existing/private-parent/new-bundle
./bootstrap/setup.sh export /existing/private-parent/new-bundle --apply
# Use the same implementation revision/content in an empty, temporary HOME:
HOME=/path/to/empty-test-home ./bootstrap/setup.sh import /path/to/new-bundle
HOME=/path/to/empty-test-home ./bootstrap/setup.sh import /path/to/new-bundle --apply
HOME=/path/to/empty-test-home ./bootstrap/setup.sh update --apply
```

Unset `XDG_STATE_HOME` for a rehearsal, or point it into that test HOME. Do not
activate the desktop during a rehearsal. Missing apps are installed separately.

The bundle includes whitelisted literal profile preferences, active-scope
overlays, display/workspace data, handwritten/captured/advisor routes, the
referenced routing pack, selected modules and implementation identity. Unknown
keys and comments are excluded. No credentials, window titles, cache, chat,
custom implementation scripts, shell config or whole-HOME archive is included.
It reproduces these intent surfaces, not every arbitrary TOML/keybinding edit.
The bundle still reveals private app/display choices: protect it accordingly.

Export refuses an existing destination and writes its completion manifest last.
Import checks schema, whitelisted paths, links, size limits, checksums, exact
implementation revision/content, canonical data and a complete staged render.
It refuses different existing intent files or extra active overlays; it never
uses an overwrite flag. A dirty checkout must be preserved at the same content,
not merely the same Git commit, to restore its bundle.

An export on the same disk is **not** an off-device backup. Choose your own
encrypted destination; nothing uploads automatically. The automated suite
rehearses an eight-workspace private profile, quiet flags, stage 4 and private
routes in a new temporary HOME. Rehearse your own bundle before relying on it.
