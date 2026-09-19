# Coexisting with dotfiles you already have

Installation uses copies, not symlinks. Preview the selected modules before
writing files, and keep your own backup of any existing setup.

## Deployment rules

1. Directories are deployed file by file. Files this repo does not ship stay in
   place. Removed upstream files are reported, not automatically deleted.
2. Each successfully copied or confirmed-identical file records a source
   checksum. On later deployments, local-only edits stay. If both local and
   upstream content differ from that baseline, deployment reports a conflict
   and keeps the local file. It does not merge the two versions.
3. Targets and their ancestors are checked for symlinks. By default a linked
   target is skipped; `--force` permits backing up and replacing the leaf link,
   never writing through a linked parent. HOME itself and macOS `/tmp` / `/var`
   aliases remain supported. This is cooperative protection, not immunity to an
   unrelated process racing a filesystem operation.
4. Recovery state must be writable before replacing a file. The source is
   staged first; a pending recovery record is written before moving an original
   to `<name>.backup_<timestamp>`. A successful operation appends to the ledger
   and removes its pending record. Failures do not advance the baseline to the
   planned source version. Inspect a nonempty pending directory after interruption.

The state directory is `${XDG_STATE_HOME:-$HOME/.local/state}/ai-first-dotfiles`.
It holds `backups.tsv`, `manifests/`, `pending/` and the cooperative `write.lock/`.
An active or abandoned lock refuses another writer. Inspect its owner PID and
unfinished operation before removing a stale lock; never bypass a live writer.

These rules have regression coverage in `deploy_engine_smoke.sh` and
`safety_boundary_smoke.sh`; they are not a general transactional filesystem.
There is no cross-file atomicity or power-loss durability guarantee. If the final
replacement fails after the original was moved, it remains at the reported
backup path. A pending record is recovery evidence, not automatic replay.

Important first-install boundary: without a successful baseline, an existing
regular file can still be backed up and replaced. Do not interpret “keep local
edits” as a promise that an unknown first-install file is never replaced.
Likewise, `--force` explicitly opts out of local-content conflict protection.

## Preview and trial

```bash
./bootstrap/setup.sh minimal --dry-run
```

The preview lists intended packages and target paths without installing them.
It is not a reservation of those paths or a complete three-way conflict report.

For a file-only trial:

```bash
trial_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-trial.XXXXXX")"
HOME="$trial_home" XDG_STATE_HOME="$trial_home/.local/state" \
  ./bootstrap/setup.sh minimal --deploy-only
find "$trial_home" -type f | head -40
```

`--deploy-only` skips package installation and desktop activation. A changed
HOME alone does **not** sandbox a process: desktop IPC still addresses the
logged-in user. Never run activation against a trial as an isolation test.
Use [the isolated test runner](testing.md) for automated regression checks.

Exit 0 means the requested steps completed; 3 means paths/modules were skipped
and the deployment is incomplete. Other nonzero codes indicate errors. A
partial deployment may already have changed other files: read the summary and
inspect backups before retrying. Do not automatically retry with `--force`.

## Pick paths you do not already manage

```bash
./bootstrap/setup.sh workspace --dry-run
./bootstrap/setup.sh capslock --dry-run
```

Leave out modules whose paths another dotfiles manager owns. In particular,
`shell` changes `~/.zshenv` to select this repo's ZDOTDIR; it is not part of
`minimal` or `developer`.

## Updates and rendering

Use `setup.sh select` to inspect/adopt a confirmed module list, then `setup.sh
update` to preview and `setup.sh update --apply` to copy only those modules while
preserving existing preference data. Do not use `all` or reapply a preset as a
preference-neutral update. Broad compatibility deployment requires `deploy --all`.

`render-layout.sh` stages generated workspace, key and app-rule blocks together
before replacing the TOML; `--no-app-rules` preserves the existing app block.
Content outside these blocks is carried through. Missing layout markers cause
refusal rather than guessing. A backup is kept beside a changed TOML. Renderer
backups are separate from the installer's ledger, not a complete undo history.

Rendering and `--deploy-only` no longer reload services. After reviewing the
actual live config, explicitly activate it:

```bash
~/.config/aerospace/activate.sh --apply
```

This checks AeroSpace's config, reloads AeroSpace, and reloads Hammerspoon when
its config and CLI are available. Errors are nonzero; a later failure does not
undo an earlier reload. Normal installation still includes its documented
launch/system-setting steps. Focus-first app routing commands remain explicit
apply operations, not read-only renderers.

`displays.conf`, `workspaces.conf` and `theme.conf` are now strict literal data.
Convert old `export`, shell commands, or computed expressions to `KEY="value"`
lines. An unsupported line reports its file/line and exits instead of executing
the file. No user config is automatically migrated.

## Recovery limitations — read before uninstalling

```bash
./bootstrap/uninstall.sh --files-only  # inspect the plan; no changes
```

The old ledger is now a **read-only recovery reference**. It does not prove
original ownership or replay pending records/renderer backups. Legacy-only
automatic uninstall refuses instead of guessing which version to restore.

New select/update/import operations have per-operation before images and hashes.
Rollback and uninstall preflight user-edit/link conflicts and retain nonempty
directories. No service/package/system reversal is inferred from file presence.
See [maintenance](maintenance.md) for the exact coverage, failure boundaries and
private restore rehearsal. Installation steps outside the new maintenance
commands still require manual legacy-backup review.

macOS permission grants, existing Homebrew state, external dotfiles managers,
and privately stored data are not restored by the deployment ledger. Treat
physical-machine recovery as unverified until you have rehearsed it.
