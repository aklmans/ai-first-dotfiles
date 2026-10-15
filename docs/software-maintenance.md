# Software updates and ownership

The shell provides an explicit updater for installed software:

```zsh
updates                    # preview commands; no upgrade commands run
update                     # run all available managers
upgrade                    # same as update
upall                      # same as update; no Topgrade dependency
update --only brew,uv       # run only selected managers
update --dry-run --only bun # preview a subset
```

These commands are deployed with the shell module. Open a new terminal after
deployment, or run `source ~/.config/zsh/aliases.zsh` to reload them. Personal
overrides in `aliases.local.zsh` / `private.zsh` still take precedence on startup.

| Group (`--only`) | Updates |
|---|---|
| `brew` | Refresh metadata, upgrade formulae (including brew-owned Node/Go/mise), then explicitly selected installed casks |
| `mise` | Standalone mise itself, then globally configured tools within their configured version ranges |
| `npm` | Global packages, excluding local links and packages linked from Homebrew/mise (including bundled npm) |
| `pnpm` | Global packages |
| `bun` | Standalone Bun itself and global packages |
| `rust` | Installed rustup toolchains; Cargo apps if `cargo-install-update` from cargo-update is already installed |
| `uv` | Standalone uv itself and all uv-installed tools |
| `go` | Versioned commands in GOBIN (or the first GOPATH/bin), using `go install path@latest` |
| `mas` | Installed App Store applications |

Package-managed Bun/uv/mise/rustup do not run competing self-updates. Select their
owner as well if using `--only`. Node and Go toolchains installed manually need
their original installer; this updater does not replace them with a new manager.
Go binaries with local replacements, development versions or custom build flags
are left alone. Cargo apps are skipped explicitly when cargo-update is absent.
Native agent/vendor GUI updaters outside these managers remain separate.

Missing managers are skipped. A failed step is reported, independent managers
continue, and the command exits nonzero; Ctrl-C stops remaining steps. Homebrew
upgrades are skipped if its metadata refresh fails. The updater honors the
private `vendor_casks` exclusions below and Homebrew's pins/default cask policy.
It does not run cleanup/autoremove, install missing managers, update macOS, or
update project dependencies. Commands run from `/` to avoid the current project's
configuration. Existing global package constraints and manager policies apply;
Homebrew formula updates can still include major runtime versions.

Preview performs only local inventory probes (brew/npm/Go); it does not contact
registries to determine all available versions. Failed probes are visible and
make the preview fail. Vendor tools may access their own metadata caches.

## Read-only inventory and guidance

Inventory is not install intent. Node/Python is an implementation technology,
not necessarily the owner of a packaged CLI. CLI and desktop apps are separate.

```bash
./bootstrap/setup.sh software plan             # local inventory + update guidance
./bootstrap/setup.sh software check            # explicit, partial version checks
./bootstrap/setup.sh software inventory --json # PRIVATE machine metadata
```

The entry point never installs, upgrades, uninstalls, restarts services, changes
PATH, runs an agent or executes its suggested commands. There is no `--apply`.
Confirm a concrete list, then use the original owner's targeted updater. This
is an inventory/check/plan surface, separate from the explicit shell updater above.

## Evidence and limits

Discovery uses Homebrew/npm/pnpm/Bun/uv/mas list commands, executable paths/links,
top-level `/Applications/*.app` and `~/Applications/*.app` Info.plist metadata,
receipt presence and `.config` names. It does not read credentials, chats, model
settings, project files or other apps' private config contents. Its own ownership
policy and explicitly approved bounded wrapper files are read. Nested Toolbox apps,
containers, inactive runtime versions and shell aliases are not exhaustively
scanned. Multiple executables may include wrappers, not duplicate installations.

Unavailable tools are reported. Failed/malformed probes produce a partial report
and exit 2, not a successful empty inventory. Stderr warnings are flagged.
mas 7's JSON object stream is parsed separately. Receipt-bearing apps absent
from its bundle-ID inventory are reported as a coverage mismatch, even when
some apps were listed successfully. Purchase/usage history and unrelated
Spotlight metadata are discarded; only scalar identity/version fields remain.
Homebrew auto-update and mas auto-indexing are disabled in probe subprocesses.
Third-party commands may still use their metadata caches; this is not an OS
sandbox or a promise of zero network activity.

JSON contains personal software choices, versions and paths: do not commit it.
Use a private destination and `umask 077` when saving a snapshot.

`check` reports these separate evidence levels:

- **Homebrew:** `outdated --json=v2` against currently
  available metadata. No `brew update` is run; no guarantee of latest upstream
  metadata. No greedy flag is used. Vendor-owned casks selected in private
  policy are excluded from this queue; app versions can exceed brew receipts.
  Never treat receipts as a reason to reinstall a self-updated app.
- **npm:** `outdated --global --json`, using the current prefix and configured
  registry. Valid outdated records with exit 1 mean updates found, not failure.
  Other Node installations and local project packages are outside this check.
- **App Store:** `outdated --json --inaccurate`, not accurate mode's trial
  downloads/dialogs. Results can be incomplete; a provider failure stays visible.
- **Native CLIs, pnpm/Bun/uv, vendor GUI updaters:** freshness is explicitly
  **not checked**. Do not run an updater with possible install/migration effects
  merely to pretend to check it. Use the vendor's review flow separately.

An empty list never means "everything on this Mac is current". No background
upgrader or scheduler is installed. Missing software is not silently installed.

## Keep one owner per product

| Distribution | Update owner | Boundary |
|---|---|---|
| Codex CLI in brew | Explicit `codex` cask | Not the desktop ChatGPT/Codex app; don't add a second npm copy |
| Claude Code native | `claude update` | Retain private channel/automatic-update choices |
| Kimi Code native | `kimi upgrade` | Legacy uv `kimi-cli` is a separate data-migration decision |
| OpenCode native | `opencode upgrade` | Review wrappers and major-version/plugin compatibility |
| pi npm | Verified installed npm namespace | Current official namespace: `@earendil-works/pi-coding-agent` |
| OpenClaw CLI | Source-aware vendor updater | Back up; Gateway/config/plugin changes can cause downtime |
| Hermes | Official updater for actual install kind | Broken links require review, not an automatic reinstall |
| App Store GUI | App Store | Numeric Store IDs and bundle IDs are different |
| Vendor-updated GUI | Vendor updater, if chosen | Feed/cask metadata does not prove auto-update is enabled |

Qoder, WorkBuddy, Dia, Arc, Warp, Typora, Kimi Desktop and ChatGPT retain their own
desktop update controls. Do not force them into npm or replace unmanaged apps
with brew copies. Choose vendor **or** brew ownership after checking the actual
installation. A similarly named brew package alone does not establish ownership.

### Enforce one owner without reinstalling

Private ownership policy lives at
`$XDG_CONFIG_HOME/ai-first/software/ownership.json` (default `~/.config/...`).
Use `--policy FILE` for another path. The empty portable example is
`manifests/software/ownership.example.json`; it selects nothing for other users.
The `vendor_casks` array lists literal brew tokens, not commands. Those products
remain visible in inventory but are omitted from the centralized update queue.

On Homebrew versions supporting cask pinning, explicitly run `brew pin --cask
TOKEN` for each product assigned to vendor/manual updating. This blocks Homebrew
upgrades without deleting the app, its install receipt, symlinks or user data.
The vendor updater still works; `brew unpin --cask TOKEN` hands control back.
The inventory checks pins and reports unprotected selected casks with exit 2.
On older Homebrew versions, unsupported pin checks stay visible; don't emulate
them by deleting Caskroom records. Pinning is not a security-update subscription:
the owner still needs to review vendor updates.

`cli_wrappers` optionally records a reviewed wrapper's absolute `path`, vendor
`target` and SHA-256. Matching bounded file contents can establish that two
entries use one binary; changing the wrapper invalidates that approval. The
inventory never evaluates wrapper code. Keep local compatibility workarounds
private and don't delete them merely to remove a second command entry.

Review updates together (for example weekly), then approve only selected targets.
Pause for busy applications/recording. Handle running services, database/runtime
major versions and agent data migrations separately. Security fixes can justify
an earlier review. Do not chain `brew cleanup`/`autoremove` into updates; package
dependency changes and migrated databases are not undone by dotfile rollback.

## Private lists, not an author's shopping list

`brew.sh apps` now reads the private
`~/.config/ai-first/software/brew-apps.txt` (honoring `XDG_CONFIG_HOME`) or an
explicit path. Missing default means no optional apps. This also changes the
optional-app part of `brew.sh all`/`packages-all`. Base/infra/desktop/font profiles
retain their existing explicit behavior; they are not routine update commands.

```bash
./bootstrap/brew.sh apps --plan --apps-manifest /your/private/brew-apps.txt
./bootstrap/app-store.sh --manifest /your/private/mas.txt
```

Brew input is literal `tap|formula|cask TOKEN`, not shell/Ruby/flags/URLs.
Examples live in `manifests/homebrew/apps.example.txt` and
`manifests/app-store/mas-personal.example.txt`, with no active app selections.
Choose desired apps explicitly; an inventory includes dependencies/experiments
and must not be auto-adopted as an install manifest.

App Store lists use `CFBundleIdentifier` from app metadata, not numeric IDs from
ordinary `mas list`. Both lists are validated before any installation. This
remains a separately confirmed install command with mas/account/region/privilege
requirements. Public default lists stay empty; personal lists belong outside Git.

Unknown config directories stay app-owned. Modification times do not establish
that data is unused. Do not export the whole `.config` tree or delete caches,
credentials, histories or old backups without a separate retention decision.
The public shell `update` function now prints guidance only. Existing live/private
shell overrides are not silently rewritten by this change.

## Official sources

- [OpenAI Codex CLI](https://learn.chatgpt.com/docs/codex/cli): multiple installation choices.
- [Claude Code setup](https://code.claude.com/docs/en/setup): source-aware updates/channels.
- [Kimi upgrade](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command#kimi-upgrade) and [legacy/new CLI](https://www.kimi.com/code/docs/en/).
- [pi namespace migration](https://pi.dev/news/2026/5/7/pi-has-a-new-home).
- [OpenCode upgrade](https://opencode.ai/docs/cli/#upgrade).
- [OpenClaw update methods](https://docs.openclaw.ai/install/updating/update-methods).
- [Hermes updates](https://hermes-agent.nousresearch.com/docs/getting-started/updating).
- [Homebrew manual](https://docs.brew.sh/Manpage) and [mas](https://github.com/mas-cli/mas).
- [Homebrew pinning and self-updating apps](https://docs.brew.sh/FAQ): separate installation records from update ownership.

Vendor behavior changes. Verify installed help/release notes before executing a
suggestion: it does not pin a reviewed release or prove download provenance.
