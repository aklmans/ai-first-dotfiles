#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Installing other people's agent skills, from a list you keep.
#
# A skill is a folder of instructions an agent will act on. Installing one is
# closer to installing a shell plugin than to downloading a document, so this
# script does what bootstrap/app-store.sh does with App Store apps: the manifest
# ships empty, the whole list is printed, and nothing is installed until you say
# so. "Install 12 skills? [y/N]" is not consent either.
#
# The installing is done by `npx skills`, the ecosystem's package manager - not
# reimplemented here. It maps skill sources onto the right directory for each of
# the seventy-odd agents that read SKILL.md, and that mapping is not something
# this repository could keep correct.
#
# --copy is passed on purpose. `npx skills` defaults to symlinking every agent
# directory at one canonical copy, and the deploy engine in lib/common.sh
# refuses to write through a symlink - it reads one as "another tool owns this
# path". Left as symlinks, the two would quietly fight over the same directory.
#
# Your own skills do not belong here. They live in home/.agents/skills/ and are
# deployed by the `skills` module, which owns those files rather than fetching
# them.
# ---------------------------------------------------------------------------

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
repo_root="$(repo_root_dir)"
default_manifest="$repo_root/manifests/skills/skills-default.txt"

usage() {
  cat <<'EOF'
Usage: ./bootstrap/skills.sh [options]

Installs the agent skills listed in manifests/skills/skills-default.txt, after
printing the list and asking. The manifest ships empty, so a fresh clone
installs nothing until you have put something in it.

Options:
  --project   Install into this project (./.agents/skills and friends) instead
              of your home directory. Run it from the project root.
  --list      Print the manifest and exit. Installs nothing, asks nothing.
  --yes       Answer yes to every prompt. For a machine you have already set up
              from your own manifest; do not use it on a fresh clone.
  -h, --help  Show this help.

Machine-level is the default: skills land in your home directory and are
available in every project. --project is the other scope, and has to be run
from the directory you mean.

Manifests:
  manifests/skills/skills-default.txt          your list
  manifests/skills/skills-personal.example.txt example, never read by this script

Finding skills:
  npx skills find <query>      search from the terminal
  https://www.skills.sh        the directory
EOF
}

assume_yes=0
list_only=0
scope_flag='--global'
scope_name='your home directory'

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --project)
      scope_flag='--project'
      scope_name="this project ($PWD)"
      ;;
    --list)
      list_only=1
      ;;
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

require_npx() {
  if ! command -v npx >/dev/null 2>&1; then
    printf 'npx is required to install skills. Install Node first (for example: brew install node), then rerun this script.\n' >&2
    printf 'Nothing was installed.\n' >&2
    exit 1
  fi
}

require_manifest() {
  if [[ ! -f "$default_manifest" || ! -r "$default_manifest" ]]; then
    printf 'manifest is missing or unreadable: %s\n' "$default_manifest" >&2
    exit 1
  fi
}

# "<source><TAB><note>" per entry, so counting, listing and installing all read
# one definition of what the manifest says.
manifest_entries() {
  local source note

  while IFS=$'\t' read -r source note || [[ -n "${source:-}" || -n "${note:-}" ]]; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    printf '%s\t%s\n' "$source" "${note:-}"
  done <"$default_manifest"
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
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  require_manifest

  local entries count source note failed=0
  entries="$(manifest_entries)"

  if [[ -z "$entries" ]]; then
    printf 'No skills listed in %s.\n\n' "${default_manifest#"$repo_root/"}"
    printf 'Add some, one per line, as "<source><TAB><why you want it>". Find them with\n'
    printf '`npx skills find <query>` or at https://www.skills.sh, and see\n'
    printf 'manifests/skills/skills-personal.example.txt for the format.\n'
    return 0
  fi

  count="$(printf '%s\n' "$entries" | wc -l | tr -d ' ')"
  printf '\nSkills (%s) from %s, for %s:\n\n' \
    "$count" "${default_manifest#"$repo_root/"}" "$scope_name"
  while IFS=$'\t' read -r source note; do
    if [[ -n "$note" ]]; then
      printf '  %-44s %s\n' "$source" "$note"
    else
      printf '  %s\n' "$source"
    fi
  done <<EOF
$entries
EOF
  printf '\n'
  printf 'Each of these is a set of instructions an agent will act on. A source naming a\n'
  printf 'repository rather than a single skill installs everything that repository ships.\n\n'

  if [[ "$list_only" -eq 1 ]]; then
    printf 'Listed only; nothing was installed.\n'
    return 0
  fi

  require_npx

  if ! confirm "Install these $count skill(s)?"; then
    printf 'Skipped. Nothing was installed.\n'
    return 0
  fi

  while IFS=$'\t' read -r source note; do
    printf '\n==> %s\n' "$source"
    # One source that has moved, been renamed or gone private must not end the
    # run and leave the rest uninstalled.
    if ! npx --yes skills add "$source" "$scope_flag" --copy --skill '*' --yes; then
      printf 'Could not install %s; continuing.\n' "$source" >&2
      failed=$((failed + 1))
    fi
  done <<EOF
$entries
EOF

  printf '\n'
  if [[ "$failed" -gt 0 ]]; then
    printf '%s skill(s) could not be installed. Check the sources above still exist.\n' "$failed" >&2
    return 1
  fi

  printf 'Installed %s skill(s). `npx skills list` shows everything now present,\n' "$count"
  printf 'and `npx skills update` refreshes them later.\n'
}

main "$@"
