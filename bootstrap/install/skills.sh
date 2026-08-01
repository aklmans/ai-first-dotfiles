#!/usr/bin/env bash
set -euo pipefail

# Deploys the skills written in this repository to ~/.agents/skills/.
#
# `.agents/skills/` rather than `.claude/skills/`: SKILL.md is an open format,
# and that path is the one agents beyond Claude Code also read. One copy serves
# all of them.
#
# This module owns only what this repository ships. Skills fetched from someone
# else are installed by bootstrap/skills.sh through `npx skills`, into the same
# directory - which is fine, because the deploy engine writes file by file and
# never removes what it did not put there.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"

parse_install_args "$@"

# A skill with no description is invisible: the description is what an agent
# reads to decide whether this is the skill for what was just asked. A skill
# with no SKILL.md is not a skill at all. Neither is worth deploying silently,
# and neither is worth failing the run over - the report names them and the
# rest still deploys.
validate_skills() {
  local root="$1"
  local skill_dir name problems=0

  [ -d "$root" ] || return 0

  for skill_dir in "$root"/*; do
    [ -d "$skill_dir" ] || continue
    name="${skill_dir##*/}"

    if [ ! -f "$skill_dir/SKILL.md" ]; then
      printf 'skills: %s has no SKILL.md, so no agent will load it.\n' "$name" >&2
      problems=$((problems + 1))
      continue
    fi

    # Frontmatter only: the fields have to be in the block at the top, not
    # somewhere in the prose further down.
    # `exit` inside a rule runs the END block before the program stops, so an
    # `exit 0` here would be overwritten by whatever END exits with. The status
    # is therefore decided in one place, in END, and the rules only record what
    # they saw.
    if ! /usr/bin/awk '
      NR == 1 && $0 != "---" { exit }
      NR > 1 && $0 == "---" { closed = 1; exit }
      /^name:[[:space:]]*[^[:space:]]/ { found_name = 1 }
      /^description:[[:space:]]*[^[:space:]]/ { found_description = 1 }
      END {
        if (closed && found_name && found_description) { exit 0 }
        exit 1
      }
    ' "$skill_dir/SKILL.md"; then
      printf 'skills: %s/SKILL.md needs both name and description in its frontmatter.\n' "$name" >&2
      problems=$((problems + 1))
    fi
  done

  [ "$problems" -eq 0 ] || printf 'skills: %s skill(s) above will not work until that is fixed.\n' "$problems" >&2
  return 0
}

if should_deploy; then
  validate_skills "$repo_root/home/.agents/skills"
  deploy_repo_path "$repo_root" "home/.agents/skills" "$HOME/.agents/skills" "$stamp"

  printf 'Skills deployed to %s.\n' "$HOME/.agents/skills"
  printf 'Other people'"'"'s skills: list them in manifests/skills/skills-default.txt and run ./bootstrap/skills.sh\n'
fi
