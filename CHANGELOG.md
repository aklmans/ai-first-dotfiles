# Changelog

Notable changes to this project. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Explicit `select` and selected-only `update` commands, with preview-first
  maintenance and separate desktop activation. Minimal updates do not adopt
  shell, Warp or media configuration.
- Private per-operation file images/hashes, failure/activation records,
  content-checked rollback and local intent export/import with restore rehearsal.
- Mandatory offline full TOML parsing on Python 3.9+ using vendored Tomli, plus
  project workspace/route checks and app-route drift detection.

- A macOS-isolated test runner with clean and author-full fixture homes, denied
  external desktop commands/network, and failure/retry regression fixtures.
- Shared deployment/render write guards, a cooperative writer lock, and minimal
  write-ahead recovery records before deployment moves an original file.
- `aerospace/activate.sh --apply` for explicit desktop reload after rendering.

- Opt-outs for background window automation and clock seconds, with behavior
  tests for display topology, routing, native Command-N and recording targets.
- A public capability catalog with composable modules and three explicit presets:
  `minimal`, `developer`, and the opinionated `author-full` reference setup.
- Exact Homebrew tap/formula/cask output in `--dry-run`; previews now disclose
  package choices as well as commands and destination paths.
- A shared, data-only preference layer for optional Hammerspoon features,
  SketchyBar item groups, the four-app notification subset, terminal choice,
  monitors and workspace groups.
- Safe exact-match AeroSpace overrides in `app-routes.conf`.
- A focus-first app route command and shortcuts for binding an app to the current
  workspace or letting it follow where it was opened.
- Semantic workspace roles, explicit `none`/`suggested`/`creator`/`author`
  routing packs, and `follow`/`prefer`/`fixed` app policies.
- A read-only resolved-plan command that shows display roles, task roles and app
  targets, and makes invalid role/route data visible to doctor and CI.
- A local installation advisor that detects display topology and recognized
  installed apps, asks about common scenes, and previews 4/6/8/10-workspace
  layouts before an explicit, backed-up `--apply`.
- Explicit `tune` feedback plus a one-shot `capture-current` route proposal;
  generated advisor/captured layers stay below handwritten app routes and use
  no background telemetry.
- A read-only module/preset doctor, choice-architecture regression suite, product
  quality scorecard and release checklist.

### Changed

- Intent import refusals now use the CLI's documented exit status and concise
  error message. Corrupt, incompatible and unsafe bundles remain rejected before
  writes; end-to-end command tests cover these paths, not just function calls.
- AI Router 2.5 requires per-request text recipients, never appends legacy
  fallback chains, and refuses unverified stock text adapters. Render, snippets
  and agent launch remain; old GUI run gestures now refuse pending a recipient UI.
- Provider requests use neutral temporary cwd, bounded input/output and owned
  process groups with timeout/cancellation cleanup. Raw failure output is
  discarded even with legacy debug switches; failures preserve the clipboard.
  Custom adapters remain trusted code, not sandboxed extensions.
- Failed Hammerspoon/SketchyBar display queries now explain why targeting stays
  unchanged instead of silently returning no identity.
- Test isolation now also denies absolute clipboard clients (`pbcopy`/`pbpaste`);
  a fake HOME alone must not give tests access to the real pasteboard.
- Release readiness uses explicit evidence and unresolved gates, not numerical
  self-scoring. Hardware, provider and third-party-user acceptance stay separate
  from isolated fixtures.

- Window/attention diagnostics are off by default; explicit short sessions write
  only bounded event codes to private files. Legacy logs are untouched.
- Bar/config reloads no longer unload macOS OSD services, install the Hammerspoon
  CLI, or change login startup settings. Those choices remain explicit.
- Display names render as escaped anchored patterns; duplicate/unknown display
  identity is reported instead of substituting another tool's monitor numbers.
- Recording preparation stops on failed move/bar/float/resize steps, checks the
  resulting frame, and does not report earlier partial steps as total success.
- Main-only bar hiding refuses unknown identity before changing gaps, propagates
  visibility failure and does not rebalance windows. Gap writes are validated,
  backed up and replaced through the shared write guard.
- JetBrains dialog-title matching uses Lua-compatible prefix checks. Doctor can
  warn about saved macOS number-key shortcut conflicts without changing them.

- Adding/reinstalling modules preserves existing preferences unless their shown
  defaults are explicitly accepted. Recording no longer selects a routing pack.
- Doctor distinguishes selected, installed, configured enablement, static config
  validity and unverified runtime; private/unknown profiles are not assumed full.
- `deploy` requires explicit `--all`; use `update` for preference-preserving
  maintenance of confirmed modules.
- Legacy ledgers are now read-only recovery references. Uninstall reverses only
  newly recorded maintenance changes and refuses user edits or unknown ownership;
  it never guesses service, package, GUI PATH or defaults restoration. Standalone
  installation/adapter actions are not a complete transactional history. See
  [maintenance and migration](docs/maintenance.md).

- Deployment preserves conflicts when both upstream and local content changed;
  failed backup/copy/manifest operations no longer claim a new successful
  baseline. Unavailable recovery state refuses deployment before replacement.
- Symlink checks include existing ancestors. `--force` can replace a leaf link
  with a backed-up copy, but cannot write through a linked parent directory.
- AeroSpace renderers and `--deploy-only` do not reload desktop services. Layout
  and app rules are staged together before replacement; render errors propagate.
- Display/workspace/theme data rejects unsupported shell syntax with file/line
  diagnostics instead of executing it as a compatibility fallback.
- `setup.sh` returns 3 for a partial deployment, not success; other failures
  remain nonzero. See [coexistence and migration notes](docs/coexisting.md).

- Recording Mode now resolves its semantic task from the shared profile/overlay
  reader on invocation instead of reading only the old workspace file. Invalid
  targets fail closed. Disabling notifications also stops the activation-clear
  watcher rather than leaving it running in the background.
- Running `setup.sh` with no module is now inert and shows the catalog. New users
  are guided to `minimal --dry-run` instead of the compatibility `all` profile.
- Shared dependencies execute once when modules are composed. Presets install a
  matching `~/.config/ai-first/profile.conf` without overwriting local edits.
- The neutral minimal preset uses six unpinned workspaces, Terminal, portable
  dialog/layout rules and user routes, but no shipped app placement,
  notifications, recording, AI hotkeys, paid apps or accounts.
- Existing no-profile deployments keep their previous full behavior; the
  `author-full` preset preserves the maintained 13-workspace desk exactly.
- Finder and Preview now follow the workspace that opened them while remaining
  floating, instead of being globally pinned to workspace 11.
- The developer preset no longer inherits the author's 13-workspace app map;
  it emits no shipped app placement and preserves its explicit eight-workspace
  layout without leaking workspace 13 back into generated rules.
- **`AI_FIRST_ROUTING_PACK="none"` now really means no shipped app placement.**
  The float rules used to carry about eighty lines of specific application names
  inside `app-defaults.sh`, and that block ran on every install whatever pack was
  selected, so a `minimal` or `developer` setup floated Clash for Windows, Logi
  Options+, 1Password, Docker, Typeless, WeChat, QQ, DingTalk, Lark, Discord,
  Zoom, Camtasia, Snagit, Spotify, NeteaseMusic, Bilibili, mpv, Apple Music and
  Podcasts because of who wrote the repo. Those names moved into routing packs:
  the widely used communication and media apps are in `suggested`, the author's
  own toolbox is in `author`. **If you run `minimal` or `developer` and want
  those apps to keep floating, set `AI_FIRST_ROUTING_PACK="suggested"` in
  `~/.config/ai-first/profile.conf`, or add exact rows to `app-routes.conf`.**
  `author-full` is unchanged: every one of those apps still floats, on the same
  workspace as before. What stays in code is behaviour rather than taste -
  dialog-title matching, JetBrains dialogs, the macOS surfaces every Mac has
  (Finder, Preview, Mail, Photos, System Settings, Activity Monitor, Archive
  Utility, App Store, Keynote, PowerPoint), and the rule that a work window
  tiles.
- `~/.config/aerospace/plan.sh` without `--check` is now a report and exits 0
  whatever it found; `--check` is what turns the same report into a non-zero
  result for doctor and CI. Both used to exit 1, which made the flag inert.
- `plan.sh` also checks the three tools that derive behaviour from the same
  config: SketchyBar's workspace list, the workspace Hammerspoon's Recording
  Mode would use, whether the Karabiner complex modification is deployed and
  enabled, and whether `~/.aerospace.toml` still matches `workspaces.conf` and
  `displays.conf`. Everything is read-only, a tool that is not installed is
  skipped with a line saying so, and `karabiner.json` is never written.
- GUI PATH installation preserves existing entries. Uninstall deliberately does
  not reverse it without recorded original ownership/value. Nonempty directories
  retained during file rollback are reported as kept, not counted as removals.
- `app-route.sh capture-current` reports how many windows it had to ignore
  because their app name or workspace could not be written as a route, instead
  of dropping them from the proposal in silence.
- `plan.sh` and `app-route.sh list` put the app name last in every table, so a
  CJK app name no longer breaks the columns: `printf` pads by bytes, and `微信`
  counted as six of them.

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

### Upgrading from an earlier checkout

A fresh install needs none of this. If you deployed a previous version of this repo,
redeploying is safe — every replaced file is backed up and recorded in
`~/.local/state/ai-first-dotfiles/backups.tsv`, and `./bootstrap/uninstall.sh` reads
that ledger — but five things need a decision from you.

1. **The shell layer is no longer part of `all`.** `./bootstrap/setup.sh all` installs
   no shell, terminal or file-manager tooling. Run `./bootstrap/setup.sh shell`
   explicitly if you want it.

2. **`~/.zshenv` now asks before taking over.** On a machine where it already points
   `ZDOTDIR` at this repo nothing is asked and nothing changes. On any other machine
   the module explains what redirecting `ZDOTDIR` does to an existing `~/.zshrc`,
   copies that file to `$ZDOTDIR/.zshrc.pre-dotfiles`, and stops unless you agree or
   pass `--force`.

3. **Vendor blocks left `.zprofile`.** Shell integrations installed by other tools
   (Amazon Q, Kiro CLI, and the like) were removed from the tracked `.zprofile`.
   Move yours into `~/.config/zsh/private.zprofile`, which is sourced and never
   tracked. `private.zsh.example` shows the shape. Until you do, those integrations
   stop loading.

4. **Karabiner no longer deploys `karabiner.json`.** The CapsLock rules install as a
   complex-modification asset, which appears under *Complex Modifications → Add rule*
   and changes nothing until you enable it. **If your profile already contains those
   rules inline, do not enable the new one** — you would get every mapping twice.
   Either ignore the entry, or delete the inline rules first and then enable it.

5. **AeroSpace resolves displays from a config file.** `~/.config/aerospace/displays.conf`
   ships empty, which means "use whatever is connected". Put your monitor names in it
   and run `~/.config/aerospace/render-layout.sh` (or just redeploy) to pin workspaces
   to specific screens the way the old hard-coded config did.

Two things happen on their own: the AI router moves its generated catalogs, caches and
usage history from `~/.config/ai-router` to `~/.local/state/ai-router` on first run,
file by file and never overwriting; and the LaunchAgent that puts Homebrew on the GUI
`PATH` now prepends rather than replacing it, so entries added by other tools survive.
An agent installed under the older label keeps running until you remove it.

### Known limitations

- **Apple Silicon only.** The AeroSpace, Hammerspoon and SketchyBar layers name the
  `/opt/homebrew` prefix in two dozen places. `setup.sh` refuses on Intel rather than
  finishing successfully and wiring nothing up. `--dry-run` still previews anywhere.
- **`Ctrl + ↑` / `Ctrl + ↓` require BetterTouchTool**, which is in `extras`. Without
  it those two keys do nothing.
- **`ai-router` is being split out** into a standalone project, `hotprompt`. It still
  installs from here in the meantime.
