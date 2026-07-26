#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# A missing rg makes the assertions below pass vacuously instead of failing.
if ! command -v rg >/dev/null 2>&1; then
  printf 'ripgrep (rg) is required by this smoke test: brew install ripgrep\n' >&2
  exit 1
fi

check_script() {
  local script="$1"
  bash -n "$script"

  local header
  header="$(head -n 1 "$script")"
  if [[ "$header" != '#!/usr/bin/env bash' ]]; then
    printf 'Missing bash shebang: %s\n' "$script" >&2
    exit 1
  fi
}

check_readme_install_scripts_executable() {
  # mktemp, not a predictable /tmp name: a shared machine could pre-create or
  # symlink the fixed path and steer what this check reads.
  local tmp_file
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/readme-install-scripts.XXXXXX")"
  local script_path

  rg -o '\./bootstrap/[A-Za-z0-9._/-]+\.sh' "$repo_root/README.md" | sort -u > "$tmp_file" || true
  while IFS= read -r script_path; do
    script_path="$repo_root/${script_path#./}"
    if [[ ! -f "$script_path" ]]; then
      printf 'README references missing install script: %s\n' "$script_path" >&2
      rm -f "$tmp_file"
      exit 1
    fi
    if [[ ! -x "$script_path" ]]; then
      printf 'README references non-executable install script: %s\n' "$script_path" >&2
      rm -f "$tmp_file"
      exit 1
    fi
  done < "$tmp_file"
  rm -f "$tmp_file"
}

for script_root in "$repo_root/bootstrap" "$repo_root/tests/smoke"; do
  while IFS= read -r script; do
    check_script "$script"
  done < <(find "$script_root" -type f -name '*.sh' | sort)
done

check_readme_install_scripts_executable
