#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# App Store installs, and why this is not part of the recommended bootstrap.
#
# Nothing else in this repository needs an App Store app. What used to live in
# mas-default.txt was one person's collection of paid, region-specific and
# vendor-utility software, and `bootstrap/app-store.sh` installed all 22 of them
# without asking - a `mas install` per line, straight off a manifest the user
# had most likely never opened.
#
# So the manifest ships empty, and every install is confirmed. The list is
# printed first, because "install 22 apps? [y/N]" is not consent either.
# ---------------------------------------------------------------------------

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
repo_root="$(repo_root_dir)"
default_manifest="$repo_root/manifests/app-store/mas-default.txt"
large_manifest="$repo_root/manifests/app-store/mas-large.txt"

usage() {
  cat <<'EOF'
Usage: ./bootstrap/app-store.sh [options]

Installs the App Store apps listed in manifests/app-store/, asking before each
list. Both manifests ship without any apps in them, so a fresh clone installs
nothing until you have put something there yourself.

Options:
  --yes       Answer yes to every prompt. For a machine you have already set up
              from your own manifests; do not use it on a fresh clone.
  -h, --help  Show this help.

Manifests:
  manifests/app-store/mas-default.txt          your list
  manifests/app-store/mas-large.txt            multi-gigabyte downloads
  manifests/app-store/mas-personal.example.txt example, never read by this script
EOF
}

assume_yes=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes)
      assume_yes=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_mas() {
  if ! command -v mas >/dev/null 2>&1; then
    printf 'mas is required for App Store installs. Install it first (for example: brew install mas), then sign into the App Store and rerun this script.\n' >&2
    exit 1
  fi
}

require_manifest() {
  local manifest_path="$1"

  if [[ ! -f "$manifest_path" || ! -r "$manifest_path" ]]; then
    printf 'manifest is missing or unreadable: %s\n' "$manifest_path" >&2
    exit 1
  fi
}

# Prints "<bundle id><TAB><name>" for every entry, so callers can count, list
# and install from one definition of what the manifest contains.
manifest_entries() {
  local manifest_path="$1"
  local bundle_id app_name

  while IFS=$'\t' read -r bundle_id app_name || [[ -n "${bundle_id:-}" || -n "${app_name:-}" ]]; do
    [[ -z "$bundle_id" || "$bundle_id" == \#* ]] && continue
    printf '%s\t%s\n' "$bundle_id" "${app_name:-$bundle_id}"
  done <"$manifest_path"
}

# Defaults to no, including when there is no terminal to ask: a script piped
# into a shell must not be able to answer this on the user's behalf.
confirm() {
  local question="$1"
  local reply=""

  if [[ "$assume_yes" -eq 1 ]]; then
    printf '%s [y/N] y (--yes)\n' "$question"
    return 0
  fi

  printf '%s [y/N] ' "$question"
  if ! read -r reply; then
    printf '\n'
    reply=""
  fi

  case "$reply" in
    [Yy]*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_manifest() {
  local manifest_path="$1"
  local description="$2"
  local entries count bundle_id app_name failed=0

  require_manifest "$manifest_path"
  entries="$(manifest_entries "$manifest_path")"

  if [[ -z "$entries" ]]; then
    printf 'No apps listed in %s; skipping %s.\n' "${manifest_path#"$repo_root/"}" "$description"
    return 0
  fi

  count="$(printf '%s\n' "$entries" | wc -l | tr -d ' ')"
  printf '\n%s (%s) from %s:\n\n' "$description" "$count" "${manifest_path#"$repo_root/"}"
  while IFS=$'\t' read -r bundle_id app_name; do
    printf '  %s (%s)\n' "$app_name" "$bundle_id"
  done <<EOF
$entries
EOF
  printf '\n'

  if ! confirm "Install these $count app(s) from the App Store?"; then
    printf 'Skipped %s.\n' "$description"
    return 0
  fi

  while IFS=$'\t' read -r bundle_id app_name; do
    # One unavailable app - wrong region, no longer sold, not in this account's
    # purchase history - must not end the run and leave the rest uninstalled.
    if ! mas install --bundle "$bundle_id"; then
      printf 'Could not install %s (%s); continuing.\n' "$app_name" "$bundle_id" >&2
      failed=$((failed + 1))
    fi
  done <<EOF
$entries
EOF

  if [[ "$failed" -gt 0 ]]; then
    printf '%s app(s) could not be installed. Check that you are signed into the App Store account that owns them.\n' \
      "$failed" >&2
  fi
}

main() {
  require_mas

  printf 'Make sure you are signed into the App Store before running this script.\n'
  install_manifest "$default_manifest" 'App Store apps'
  install_manifest "$large_manifest" 'large App Store downloads'
}

main "$@"
