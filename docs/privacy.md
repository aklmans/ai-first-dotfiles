# Privacy and Public Safety

This repository is designed to be public-safe.
Only public configuration and minimal bootstrap helpers are tracked.

## Public safety policy

This project does **not** import private Git history.
Only current, reviewed, public-safe files are tracked.

That means:

- Existing repository history is not exposed here.
- Contributors should rotate secrets that may still exist in the old project history.
- Runtime and private local files are intentionally excluded.

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

- `home/.config/zsh/private.zsh` (private local shell vars, if needed)
- `home/.config/ai-router/.env.local.example` as a template only

Every `*.example` file here is a placeholder.
Copy and fill it at your private local location; never commit a filled version.

## Excluded legacy and deprecated modules

The following are excluded from this repository by design:

- `home/.config/skhd`
- `home/.config/yabai`
- `home/.config/wezterm`
- `home/.config/oh-my-posh`
- `bootstrap/install/warp-launch-agent.sh`
- `home/.config/aerospace/warp-launch-agent.sh`
- `bootstrap/install/gbrain.sh` and `templates/gbrain/` — cloned a private
  repository and required a toolchain nothing else here uses, so it could never
  have run for anyone outside that account

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
