# Changelog

Notable changes to this project. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-07-26

**The first version anyone other than the author can run.**

Everything before this was a working setup that happened to be public. It hard-coded
one person's monitors, deployed one person's shell environment, replaced whole
directories in `$HOME` without asking, aborted the entire install when any single
module failed, and had no tests. This release is that gap closed, in nine passes.

### Added

- **A regression suite and CI.** Twelve smoke suites, run on `macos-latest` for every
  push and PR, plus the router's own tests. They execute the real install scripts
  against throwaway `$HOME` directories — and specifically under `/bin/bash` 3.2, the
  bash macOS actually ships, so a bash 5 convenience cannot slip in unnoticed. They
  cover the deploy engine's guarantees, `setup.sh` orchestration and failure
  isolation, the shell-layer takeover, display resolution, the SketchyBar theme path,
  the router CLI contract, and the privacy rules.
- **`bootstrap/uninstall.sh`.** Replays the backup ledger newest-first. Prints the
  plan and changes nothing without `--apply`. Removes only files byte-identical to
  what this repo shipped, moves anything you edited aside, never touches symlinks or
  non-empty directories, and reverts the two system settings the install changed.
- **A preflight check.** `setup.sh` verifies Apple Silicon, Homebrew, git and the
  Xcode Command Line Tools before writing anything, and stops with one readable
  message instead of dying halfway through with `command not found`. `--dry-run` only
  warns, so previewing works on any machine.
- **`--dry-run` that shows paths, not just commands.** It now reads the
  `deploy_repo_path` calls out of each module and prints every path under your `$HOME`
  the run would write, marked `new` or `exists`, with the file count for directories.
- **A `theme.conf` for SketchyBar.** Fonts, sizes, geometry and colour roles in one
  file, read by the bar, Hammerspoon's recording layout and AeroSpace's top gap.
  Changing the bar height used to mean hand-aligning the same number in four files.
- **`displays.conf` and `workspaces.conf` for AeroSpace.** How many workspaces exist
  and which monitor plays which role, in two files, rendered into `~/.aerospace.toml`
  by `render-layout.sh` and `render-app-rules.sh`. Plus `doctor.sh`, which reports
  where the desk, the config and the TOML disagree.
- **An `extras` profile** for BetterTouchTool (paid after 45 days) and Warp (closed
  source, wants an account), so `setup.sh all` no longer installs software the docs
  called optional.
- **English prompt set** for the AI router, with the Chinese prompts kept under
  `prompts/zh/`.
- **`stdin` input for `ai-router`**, so it works without macOS selection APIs — and
  is testable on any machine.
- Community infrastructure: this changelog, `CONTRIBUTING.md`, and a bug report
  template that asks for the `--dry-run` output.

### Changed

- **The deploy engine was rewritten.** It replaced whole directories, which meant a
  redeploy wiped every prompt, SketchyBar item and router file you had added next to
  the tracked ones. It now deploys file by file, keeps files you edited yourself
  (reported as `Kept local change`), backs up anything it does replace and writes it
  to a ledger, refuses to write through a symlink another dotfiles manager owns, and
  reports the paths it left untouched instead of silently overwriting them.
- **One failing module no longer ends the run.** A brew hiccup inside `sketchybar`
  used to mean borders, Hammerspoon, the router and mpv were never reached, with one
  error from the middle of the list and no way to tell what had installed. Every
  step's exit code is now captured, the run continues to the end, and failures are
  listed together. Interrupts (`SIGINT`/`SIGTERM`) still stop immediately.
- **`--deploy-only` deploys.** It used to also launch apps and restart brew services.
- **The shell layer left `setup.sh all`.** Installing it repoints `~/.zshenv` at this
  repo, which is the most invasive thing in here; it is now `setup.sh shell`.
- **Displays and workspaces come from config, not from the author's desk.** With
  `displays.conf` empty, `main`, `side` and `stage` all resolve to whatever is
  actually connected, so a MacBook with no external display works out of the box and
  nothing waits at login for a monitor that is not there.
- **SketchyBar runs without AeroSpace.** The bar no longer assumes the tiling layer
  is installed and running.
- **Karabiner ships a rule, not a profile.** `~/.config/karabiner/karabiner.json` is a
  keyboard driver's live state — every profile, device override and enabled rule the
  user has. Copying this repo's version over it replaced all of that. The install now
  drops a complex-modifications asset that adds an option and changes no active
  mapping until you enable it. The tracked `karabiner.json` is a reference copy and is
  never deployed.
- **The AI hotkeys run the action.** `CapsLock + Shift + letter` sends the prompt to a
  provider instead of only rendering it to the clipboard.
- **The provider list is open.** `ai-router` no longer carries a hard-coded whitelist;
  drop a script in `providers/` and it is available.
- Documentation was reorganised: a `docs/README.md` index, a cost table in the README
  for what each profile installs and takes over, the macOS permission table extended
  to AeroSpace and SketchyBar, and an explicit list of the shortcuts that collide with
  macOS defaults.

### Fixed

- **`~/.zshenv` no longer silently disables an existing `~/.zshrc`.** Pointing
  `ZDOTDIR` at this repo made the user's own `~/.zshrc` stop being read, with no
  message.
- **The author's private shell environment stopped shipping** — personal paths,
  personal aliases and machine-specific variables. Machine-local values belong in
  `~/.config/zsh/private.zsh`, which is not tracked.
- **Security-weakening `defaults write` calls removed**, and the rest moved to
  `examples/macos-defaults/`, which no profile ever runs.
- **Empty array expansion under bash 3.2.** `"${arr[@]}"` on an empty array is an
  unbound variable in the bash macOS ships, and it aborted scripts under `set -u`.
- **Predictable `/tmp` paths replaced with `mktemp`** in the test suite, where a
  shared machine could have pre-created or symlinked the fixed path.
- **Smoke tests fail loudly when ripgrep is missing.** Every `rg`-based assertion used
  to exit 127 and pass vacuously — the privacy scan included.
- SketchyBar workspace refreshes are coalesced instead of firing per event.
- AeroSpace app placement is restored on startup.
- Vendored assets no longer drive GitHub's language statistics.

### Removed

- **`bootstrap/install/gbrain.sh` and `templates/gbrain/`.** They cloned a private
  repository and needed a toolchain nothing else here uses, so they could never have
  run for anyone outside one account.
- Machine-specific defaults, personal app inventories and private workspace maps.
  `manifests/app-store/mas-default.txt` now ships empty and `app-store.sh` asks before
  installing anything.

### Known limitations

- **Apple Silicon only.** The AeroSpace, Hammerspoon and SketchyBar layers name the
  `/opt/homebrew` prefix in two dozen places. `setup.sh` refuses on Intel rather than
  finishing successfully and wiring nothing up. `--dry-run` still previews anywhere.
- **`Ctrl + ↑` / `Ctrl + ↓` require BetterTouchTool**, which is in `extras`. Without
  it those two keys do nothing.
- **`ai-router` is being split out** into a standalone project, `hotprompt`. It still
  installs from here in the meantime.
