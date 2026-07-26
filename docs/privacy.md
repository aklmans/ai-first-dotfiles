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

The AI layer stores none. Every provider under
`home/.config/ai-router/providers/` shells out to a CLI you have already signed
into — `codex`, `claude`, `gemini`, `kimi`, `ollama` — so no API key is ever read
from, written to, or tracked in this repository.

`home/.config/ai-router/lib/router_tools.py` additionally redacts anything
shaped like `api_key`, `token`, `password`, `secret` or `bearer` out of error
text before it reaches the log.

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
