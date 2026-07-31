# Local choices

`profile.conf` is the machine-owned preference layer. A named setup preset
creates it; the repository never ships one inside `home/`, so ordinary config
deployment cannot silently change the user's selected preset.

The runtime order is:

1. safe built-in behavior;
2. the selected preset copied to `profile.conf`;
3. explicit module additions in `modules/<preset>/`;
4. environment variables for one-off overrides.

Choose or preview a preset from the repository root:

```bash
./bootstrap/setup.sh minimal --dry-run
./bootstrap/setup.sh developer
./bootstrap/setup.sh author-full
```

Edit `profile.conf` after installation to make the preset yours. Re-running the
same preset keeps local edits; pass `DOTFILES_FORCE=1` only when intentionally
returning to the repository's version.

Module additions are scoped by preset. A notification module added to `minimal`
does not unexpectedly follow you to `developer`; returning to `minimal` restores
that choice. Module-only composition uses the `custom` scope.
