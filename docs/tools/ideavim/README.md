# IdeaVim

`home/.ideavimrc` holds the Vim-mode settings for JetBrains IDEs, so editing
inside IntelliJ, GoLand or PyCharm behaves like editing anywhere else in this
setup.

## Install

```bash
./bootstrap/install/ideavim.sh
```

That deploys one file, `~/.ideavimrc`, and installs nothing. It is also part of
the `shell` profile:

```bash
./bootstrap/setup.sh shell
```

The IDE picks it up on the next restart, or via `:source ~/.ideavimrc`. IdeaVim
itself is a JetBrains plugin — install it from the IDE's plugin marketplace;
nothing here can do that for you.

## Notes

- Configuration only. No IDE runtime data, workspace files or project snapshots
  are tracked, and none should be added to `.ideavimrc`.
- Keep IDE-specific or machine-specific settings in your own IDE config rather
  than here.
- The deploy engine keeps your edits: once `~/.ideavimrc` differs from the copy
  the last install wrote, a redeploy reports `Kept local change` and leaves it
  alone. Re-run with `--force` to take the shipped version back.
