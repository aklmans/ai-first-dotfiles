# Contributing

Thanks for looking. This is one person's macOS setup made reusable, so the bar
for changes is less "is this a good idea" and more "does this stay true on a
machine that is not the author's".

## Run the tests

Everything is shell. There is no build step.

```bash
brew install ripgrep                       # the suite hard-fails without it
for t in tests/smoke/*.sh; do
  printf '\n==> %s\n' "$t"
  bash "$t" || echo "FAILED: $t"
done

bash home/.config/ai-router/tests/run.sh   # the router's own tests
```

That is exactly what [CI](.github/workflows/ci.yml) runs on `macos-latest`, so a
green local run is a green PR.

The smoke suites cover the repo:

| Suite | Covers |
|---|---|
| `repository_structure_smoke.sh` | Every tracked path that must exist, and every one that must not |
| `privacy_scan_smoke.sh` | Secrets, real home paths, device ids, runtime dirs |
| `install_script_syntax_smoke.sh` | `bash -n` and shebangs on every script; every `./bootstrap/*.sh` path named in `README.md` exists and is executable |
| `install_script_side_effects_smoke.sh` | No module writes outside its declared targets |
| `install_deploy_smoke.sh` | Module scripts run for real against a throwaway `$HOME` |
| `deploy_engine_smoke.sh` | The four deploy guarantees: per-file, keep-local, back-up, never-follow-symlinks |
| `orchestration_smoke.sh` | `setup.sh` profiles, flag handling, failure isolation, preflight |
| `choice_architecture_smoke.sh` | catalog validity, preset behavior, cost boundaries and copy deployment |
| `shell_layer_smoke.sh` | `~/.zshenv` takeover, `ZDOTDIR`, not clobbering an existing `~/.zshrc` |
| `aerospace_workflow_smoke.sh` | Renderers, display resolution, workspace math |
| `advisor_displays_smoke.sh` | Display detection off the author's desk: no built-in screen, resolving a display by number, degenerate detection |
| `route_merge_smoke.sh` | The four route layers, the legacy layout-only merge, and the workspace whitelist |
| `overlay_scope_smoke.sh` | Module preference overlays are written where the runtime reads them, and never overwrite the profile they land beside |
| `portability_smoke.sh` | awk portability: no `-v` name shadowing a built-in, no doubled `\n` in a format string |
| `config_injection_smoke.sh` | Which user-editable config files are data and which are shell: the `displays.conf` / `workspaces.conf` grammar, the compatibility fallback, and a hostile value in `theme.conf` |
| `cross_tool_consistency_smoke.sh` | `plan.sh` exit codes, the four-tool agreement it checks, `none` meaning no shipped app placement, and CJK-safe columns |
| `sketchybar_smoke.sh` | Theme sourcing, display resolution, running without AeroSpace |
| `ai_router_cli_smoke.sh` | Router CLI contract |
| `ai_router_exports_smoke.sh` | Exported snippets match the prompts |

Running a single suite is just `bash tests/smoke/<name>.sh`.

## bash 3.2, not bash 5

macOS ships **bash 3.2.57** and that is what these scripts run under in the
field. `install_deploy_smoke.sh`, `orchestration_smoke.sh`,
`shell_layer_smoke.sh` and `sketchybar_smoke.sh` all execute the real scripts
through `/bin/bash` and refuse to run if it is not 3.2, precisely so a bash 5
convenience cannot slip in unnoticed.

What that rules out:

- `${var,,}` / `${var^^}` case conversion
- Associative arrays (`declare -A`)
- `mapfile` / `readarray`
- `&>>`, `|&`
- Negative array indices, `${arr[-1]}`
- `"${arr[@]}"` on an empty array under `set -u` — it is an unbound variable in
  3.2 and aborts the script. Use the guarded form this repo uses throughout:

  ```bash
  parse_install_args ${args[@]+"${args[@]}"}
  ```

If you need a newer bash, you need a different design.

## Rules that are not negotiable

**Nothing writes to `$HOME` except `deploy_repo_path`.** It is the single
chokepoint in `bootstrap/lib/common.sh`, and it is what makes the backup ledger,
the uninstaller, and `--dry-run`'s path preview possible. A `cp` straight into
`$HOME` in a module script bypasses all three.

**Copies, never symlinks.** And never write through a symlink you find at the
target — that means another dotfiles manager owns the path.

**Never delete a user's file.** Replace it and back it up, or leave it. The
uninstaller only removes files byte-identical to what this repo shipped.

**No `/opt/homebrew`-shaped absolute paths in new code** unless the desktop
layer already forces it, and no `/Users/<name>` anywhere — the privacy scan
fails the build on both.

**Every install script must be idempotent.** Running it twice is normal; running
it twice must be boring.

## What is unlikely to be merged

- **New GUI apps in a neutral preset.** Optional software gets its own outcome-
  named module, with cost and permissions in `bootstrap/catalog.sh`.
- **Anything that makes `minimal` implicit or more invasive.** No-argument setup
  stays inert. A dependency belongs in a preset only when that preset's promised
  outcome cannot work without it.
- **Personal inventories.** App lists, machine-specific workspace maps, your
  monitor names. `displays.conf`, `workspaces.conf` and `theme.conf` exist so
  those live on your machine and not in this repo.
- **Whole-config takeovers of apps that own their own state.** Karabiner's
  `karabiner.json` is the standing example: this repo ships a
  complex-modification asset instead, and a PR that deploys the profile will be
  declined. `privacy_scan_smoke.sh` asserts it.
- **Reformatting or renaming without a behavior change.** The comments in
  `bootstrap/lib/common.sh` and `setup.sh` explain *why* the code is shaped the
  way it is; they are load-bearing.
- **New dependencies for something already solvable in shell.** No Python
  packages, no Node, no Ruby.

## Documentation

- Docs live in `docs/`. `docs/README.md` is the index — add new pages there
  rather than growing the README's link list.
- The README is for a stranger deciding whether to run this. Keep it concrete:
  numbers, paths, and what breaks.
- If you change a public module, update `bootstrap/catalog.sh`, the choice docs
  and the choice-architecture test. Package/path truth comes from `--dry-run`.

## Commits and PRs

- One concern per PR. The nine cleanup batches this repo just went through were
  each a single concern, and the history is readable because of it.
- Commit subjects: `fix:`, `feat:`, `docs:`, `test:`, `chore:`, `ci:` — imperative,
  lowercase, no trailing period.
- Say what breaks without the change, not what the change does. The diff already
  says what it does.
- Add a test when you fix something. Every bug fixed in this repo has one.
