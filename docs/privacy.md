# Privacy and Public Safety

A dotfiles repo is a machine snapshot, and machine snapshots leak. This page is
the policy that keeps this one from leaking, and
[`tests/smoke/privacy_scan_smoke.sh`](../tests/smoke/privacy_scan_smoke.sh)
enforces it on every push.

## What the scan blocks

The check fails the build — it is not advisory — on any of:

- A token-shaped string: `sk-…`, `ghp_…`, `github_pat_…`, `AKIA…`, `xox[baprs]-…`
- A private key header
- An `api_key` / `access_token` / `bearer_token` assignment with a real-looking value
- **Any real absolute home path.** `/Users/<anything>` fails unless it is one of
  the documented placeholders (`/Users/YOUR_USERNAME`, `/Users/you`,
  `/Users/alice`, …). Use `$HOME`.
- A file named `*.env*`, `*secret*`, `*token*`, `*backup*` or `*.bak`
- A directory named `cache`, `logs` or `state`
- Hardware identifiers in the Karabiner config (see below)

## Runtime / state exclusions

The following directories are excluded by design and are not tracked:

- `home/.config/ai-router/cache/`
- `home/.config/ai-router/logs/`
- `home/.config/ai-router/state/`
- `home/.config/ai-router/catalogs/`
- `**/cache/`, `**/logs/`, `**/state/`

## What to keep local

- API keys, tokens, passwords, or cookies.
- `*.env` and other secret-bearing credentials.
- `~/.local/bin/`, private SSH keys, personal tokens, OAuth files.
- Runtime artifacts such as:
  - IDE workspace/session files
  - Browser caches
  - Home app cache and private service state

Use private overrides:

- `~/.config/zsh/private.zsh` — machine-specific shell variables and secrets.
  Never tracked. `home/.config/zsh/private.zsh.example` shows the shape.

Every `*.example` file here is a placeholder.
Copy and fill it at your private local location; never commit a filled version.

## Credentials

The repository supplies no credentials. Rendering is local; coding clients
manage their own credentials and retention. Stock text adapters are quarantined
pending isolation verification. Custom adapters are trusted executable code and
may use credentials outside this repository; installing a CLI is not consent to
send a request to it.

Router text execution requires explicit per-request recipients. Failure logs
contain router-generated status metadata, never raw provider stdout/stderr.
Legacy raw-debug switches are ignored; regex redaction is not a secret filter
guarantee. Successful output is still cached, and render-only may cache selected
text. Existing logs/caches and external-client histories are not removed by an
update. See [AI execution and cancellation limits](tools/ai-router/safety.md).

## What the notification module reads, and what it keeps

The `notifications` module is the one capability here that reads a system
database and writes something derived from it to disk. It is off in every preset
except `author-full`, and the advisor never turns it on. If you enable it, this
is the whole of what it does.

| | |
|---|---|
| Reads | `~/Library/Group Containers/group.com.apple.usernoted/db2/db`, opened with `sqlite3 -readonly`. That is why the module asks for Full Disk Access. |
| How often | Every 5 seconds, while SketchyBar is running (`items/ai_notifications.sh`, `update_freq=5`). It is a poll on the bar's own timer, not a background daemon, and it stops when the bar stops. |
| Filters to | Warp, Codex, IntelliJ IDEA and GoLand only — the four in `AI_FIRST_NOTIFICATION_APPS`. An application outside that list is not read out of the database. |
| Writes | `~/Library/Caches/sketchybar/ai_attention.json`, holding a per-app count, `updated_at`, and **the notification title** for the four apps above. |
| Sends | Nothing. There is no network call anywhere in this module. |

The stored title is the same text macOS already showed you in the corner of the
screen, and it is what the bar's popup displays. It still means notification
text from those four apps sits in a cache file in plain JSON. To see it, or to
clear it:

```bash
cat ~/Library/Caches/sketchybar/ai_attention.json
rm -f ~/Library/Caches/sketchybar/ai_attention.json
```

It is rebuilt on the next poll. To stop it entirely, set
`AI_FIRST_FEATURE_NOTIFICATIONS="0"` in `~/.config/ai-first/profile.conf` and
restart SketchyBar, or remove the module's overlay under
`~/.config/ai-first/modules/<preset>/notifications.conf`.

“No telemetry” on this page has always meant *nothing leaves your machine*, and
that remains true. It has never meant *nothing is written down*, and this page
previously did not say which local state existed.

## Window diagnostics

Hammerspoon's workspace and attention helpers do not log by default. For a short
diagnostic session, set `wowDiagnosticsUntil = os.time() + 900` in its Console;
set it to `nil` to stop early. No portable preference silently re-enables it.
Only fixed event codes, timestamps and numeric exit statuses are accepted by
the writer. Window titles, app names, paths and raw stderr are not written.

Opt-in output is `~/.hammerspoon/diagnostics/events.log`: directory mode `0700`,
file mode `0600`, capped at 64 KiB. Existing content older than 24 hours is
discarded **on the next enabled write**, not by a background cleanup service.
If diagnostics are never used again, the last file remains until you remove it.
Linked paths, non-private permissions and non-regular files are refused.

Old `/tmp/hammerspoon-workspace-inherit.log`, its `.1` rotation and
`/tmp/hammerspoon-app-reveal.log` may contain titles. Updating does not read,
upload, chmod or delete them. Decide separately whether to retain or remove
your own old logs. Notification caches and AI-router logs have separate policies;
these changes do not certify those optional modules.

## Personal inventories

App Store manifests are the easiest place for a machine snapshot to survive a
review, because a bundle id does not look like personal data until you read the
list. `manifests/app-store/mas-default.txt` therefore ships empty, and
`bootstrap/app-store.sh` prints what it is about to install and asks first.
`manifests/app-store/mas-personal.example.txt` is one person's list, kept as a
format example and never read by any script.

Karabiner configuration deserves the same care in the other direction:
`home/.config/karabiner/karabiner.json` carries `vendor_id`/`product_id` pairs
identifying the exact keyboards a person owns. The tracked copy has none, and
the install module deploys a complex-modifications asset rather than the
profile. `tests/smoke/privacy_scan_smoke.sh` asserts both.

## Screenshot safety

Any image or command output shared in docs or examples must be sanitized.
Do not include real account names, real paths, real chats, production URLs, or tokens.

## Recommended checks before sharing

- Run privacy smoke checks:
  - `bash tests/smoke/privacy_scan_smoke.sh`
  - `bash tests/smoke/repository_structure_smoke.sh`
- Keep a clean commit history and avoid adding private files by accident.
- Review diffs for unexpected machine-specific paths before publishing.
