#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Without ripgrep every assert_no_matches below exits 127, which used to fall
# through as "no matches" and pass the whole secret scan vacuously.
if ! command -v rg >/dev/null 2>&1; then
  printf 'ripgrep (rg) is required by this scan: brew install ripgrep\n' >&2
  exit 1
fi

python_cache_dir="$(mktemp -d)"
tmp_scan_root="$(mktemp -d)"
abs_path_matches_file="$tmp_scan_root/absolute-path-matches.txt"
sensitive_file_names_file="$tmp_scan_root/sensitive-file-names.txt"
runtime_dir_matches_file="$tmp_scan_root/runtime-dirs.txt"
karabiner_lint_file="$tmp_scan_root/karabiner.json.lint"
trap 'rm -rf "$python_cache_dir" "$tmp_scan_root"' EXIT
scan_targets=(
  "$repo_root/home"
  "$repo_root/bootstrap"
  "$repo_root/manifests"
  "$repo_root/docs"
  "$repo_root/tests"
  "$repo_root/README.md"
  "$repo_root/LICENSE"
)

assert_no_matches() {
  local message="$1"
  local pattern="$2"
  shift 2

  local output status=0
  output="$(rg -n -P --hidden --glob '!.git/*' -e "$pattern" "$@" 2>&1)" || status=$?
  if [[ "$status" -eq 0 ]]; then
    printf '%s\n' "$output" >&2
    printf '%s\n' "$message" >&2
    return 1
  fi
  # Only 1 means "searched successfully, found nothing". Anything else (2 for a
  # bad pattern, 127 for a missing rg) must fail loudly rather than pass as clean.
  if [[ "$status" -ne 1 ]]; then
    printf '%s\n' "$output" >&2
    printf 'Privacy scan command failed with status %s; treating as a failure.\n' "$status" >&2
    return 1
  fi
}

assert_path_absent() {
  local relative_path="$1"
  if [[ -e "$repo_root/$relative_path" ]]; then
    printf 'Unexpected tracked path present: %s\n' "$relative_path" >&2
    exit 1
  fi
}

# strict token-like patterns (high-confidence only)
assert_no_matches \
  'High-confidence secret-like token leaked in configuration or scripts' \
  '(?i)\b(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,})\b' \
  "${scan_targets[@]}"

assert_no_matches \
  'Private key header found in migrated files' \
  '(?i)BEGIN[[:space:]]+[A-Z0-9 _-]+[[:space:]]+PRIVATE[[:space:]]+KEY' \
  "${scan_targets[@]}"

assert_no_matches \
  'API-like assignment with secret-like value found in migrated files' \
  "(?i)(api[_-]?key|access[_-]?token|bearer[_-]?token|secret[_-]?token)\\s*[=:]\\s*[\\\"']?(?!YOUR_)[A-Za-z0-9_./:+-]{20,}[\\\"']?" \
  "${scan_targets[@]}"

assert_no_matches \
  'Public Kaku assistant config must not hard-code private or third-party API endpoints' \
  'api\.vivgrid\.com' \
  "$repo_root/home/.config/kaku"

assert_no_matches \
  'Public zsh aliases should not expose personal directory topology' \
  'Knowledge|Documents/Personal|Assets/Archive/Pending' \
  "$repo_root/home/.config/zsh/aliases.zsh"

assert_no_matches \
  'Public zsh aliases should not contain destructive cleanup shortcuts' \
  'sudo rm -rf' \
  "$repo_root/home/.config/zsh/aliases.zsh"

# block suspicious machine-bound absolute paths from migrated sources
grep -RIn --binary-files=without-match --exclude="privacy_scan_smoke.sh" '/Users/aklman' "${scan_targets[@]}" > "$abs_path_matches_file" || true
if [ -s "$abs_path_matches_file" ]; then
  cat "$abs_path_matches_file" >&2
  printf 'Absolute path leaked in migrated sources\n' >&2
  exit 1
fi

# block runtime and obsolete folders from tracked sources
assert_path_absent "home/.config/skhd"
assert_path_absent "home/.config/yabai"
assert_path_absent "home/.config/wezterm"
assert_path_absent "home/.config/oh-my-posh"
assert_path_absent "home/.config/aerospace/warp-launch-agent.sh"
assert_path_absent "bootstrap/install/warp-launch-agent.sh"

assert_path_absent "home/.config/ai-router/cache"
assert_path_absent "home/.config/ai-router/logs"
assert_path_absent "home/.config/ai-router/state"
assert_path_absent "home/.config/ai-router/catalogs"

assert_path_absent "apps"
assert_path_absent "docs/tools/skhd"
assert_path_absent "docs/tools/yabai"
assert_path_absent "docs/tools/wezterm"
assert_path_absent "docs/tools/oh-my-posh"

# block common sensitive file naming patterns while skipping .git internals
find "$repo_root" \
  -path "$repo_root/.git" -prune -o \
  -type f \
  \( -iname "*.env*" -o -iname "*secret*" -o -iname "*token*" -o -iname "*backup*" -o -iname "*.bak" \) \
  ! -path "$repo_root/templates/gbrain/.env.local.example" \
  ! -path "$repo_root/templates/gbrain/codex-config.example.toml" \
  ! -path "$repo_root/home/.config/ai-router/.env.local.example" \
  -print > "$sensitive_file_names_file"
if [ -s "$sensitive_file_names_file" ]; then
  printf 'Sensitive file naming pattern found under repo\n' >&2
  head -n 20 "$sensitive_file_names_file" >&2
  exit 1
fi

find "$repo_root" \
  -path "$repo_root/.git" -prune -o \
  -type d \( -name cache -o -name logs -o -name state \) \
  -print > "$runtime_dir_matches_file"
if [ -s "$runtime_dir_matches_file" ]; then
  printf 'Sensitive runtime directory found under repo\n' >&2
  head -n 20 "$runtime_dir_matches_file" >&2
  exit 1
fi

# JSON/Python sanity checks
python3 -m json.tool "$repo_root/home/.config/karabiner/karabiner.json" >"$karabiner_lint_file"
PYTHONDONTWRITEBYTECODE=1 \
PYTHONPYCACHEPREFIX="$python_cache_dir" \
python3 -m py_compile "$repo_root/home/.config/ai-router/lib/router_tools.py"

bash "$repo_root/tests/smoke/ai_router_exports_smoke.sh"
HOME="$repo_root/home" bash "$repo_root/home/.config/ai-router/tests/run.sh"

echo "privacy_scan_smoke.sh: ok"
