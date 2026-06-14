#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" == *"$needle"* ]] || {
    printf '%s: missing %s\n' "$label" "$needle" >&2
    exit 1
  }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" != *"$needle"* ]] || {
    printf '%s: unexpected %s\n' "$label" "$needle" >&2
    exit 1
  }
}

toml="$(cat "$repo_root/home/.aerospace.toml")"
assert_not_contains "$toml" "warp-launch-agent.sh" "AeroSpace config"
assert_contains "$toml" ".config/ai-router/ai-router.sh agent codex" "Codex agent binding"
assert_contains "$toml" ".config/ai-router/ai-router.sh agent claude" "Claude agent binding"
assert_not_contains "$toml" "agent-run codex" "Codex binding must not auto-run"
assert_not_contains "$toml" "agent-run claude" "Claude binding must not auto-run"
assert_contains "$toml" "com.obsproject.obs-studio" "OBS workspace binding"
assert_contains "$toml" "move-node-to-workspace 11" "OBS workspace target"
assert_contains "$toml" "com.bilibili.bilibiliPC" "Bilibili workspace binding"
assert_contains "$toml" "move-node-to-workspace 10" "Bilibili workspace target"
assert_contains "$toml" "com.blade.shadow-macos" "Shadow workspace binding"
assert_contains "$toml" "ShadowPCDisplay" "Shadow app-name fallback"

hammerspoon="$(cat "$repo_root/home/.hammerspoon/init.lua")"
assert_contains "$hammerspoon" 'jetbrainsDefaultWorkspace = "2"' "Hammerspoon JetBrains default workspace"
assert_contains "$hammerspoon" '["com.obsproject.obs-studio"] = "11"' "Hammerspoon OBS fixed workspace skip"
assert_contains "$hammerspoon" '["com.bilibili.bilibiliPC"] = "10"' "Hammerspoon Bilibili fixed workspace skip"
assert_contains "$hammerspoon" '["com.blade.shadow-macos"] = "2"' "Hammerspoon Shadow fixed workspace skip"

rules="$("$repo_root/home/.config/aerospace/app-defaults.sh" --toml)"
assert_contains "$rules" "Refactor" "JetBrains floating dialog matcher"
assert_contains "$rules" "com.obsproject.obs-studio" "Generated OBS workspace binding"
assert_contains "$rules" "com.bilibili.bilibiliPC" "Generated Bilibili workspace binding"
assert_contains "$rules" "com.blade.shadow-macos" "Generated Shadow workspace binding"

cp "$repo_root/home/.aerospace.toml" "$tmp_dir/.aerospace.toml"
mkdir -p "$tmp_dir/bin" "$tmp_dir/.config/aerospace"

cat > "$tmp_dir/bin/aerospace" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  list-monitors)
    printf '1\tPHL 279C9\t3\n'
    printf '2\tBuilt-in Retina Display\t1\n'
    printf '3\t24V5C2\t2\n'
    ;;
  reload-config|balance-sizes)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
SH

cat > "$tmp_dir/bin/hs" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'Built-in Retina Display\t1\tUUID-BUILTIN\n'
printf '24V5C2\t2\tUUID-SIDE\n'
printf 'PHL 279C9\t3\tUUID-MAIN\n'
SH

cat > "$tmp_dir/bin/sketchybar" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log="${SKETCHYBAR_TEST_LOG:?}"
if [ "${1:-}" = "--query" ] && [ "${2:-}" = "displays" ]; then
  cat <<'JSON'
[
  {"arrangement-id":1,"DirectDisplayID":1,"UUID":"UUID-BUILTIN"},
  {"arrangement-id":2,"DirectDisplayID":3,"UUID":"UUID-MAIN"},
  {"arrangement-id":3,"DirectDisplayID":2,"UUID":"UUID-SIDE"}
]
JSON
  exit 0
fi
printf '%s\n' "$*" >> "$log"
SH

chmod +x "$tmp_dir/bin/aerospace" "$tmp_dir/bin/hs" "$tmp_dir/bin/sketchybar"

export HOME="$tmp_dir"
export AEROSPACE_BIN="$tmp_dir/bin/aerospace"
export HS_BIN="$tmp_dir/bin/hs"
export SKETCHYBAR_BIN="$tmp_dir/bin/sketchybar"
export SKETCHYBAR_CONFIG_DIR="$repo_root/home/.config/sketchybar"
export SKETCHYBAR_TEST_LOG="$tmp_dir/sketchybar.log"

bash "$repo_root/home/.config/aerospace/toggle-sketchybar-space.sh" hide-main

if ! grep -F -- '--bar hidden=off display=1,3' "$SKETCHYBAR_TEST_LOG" >/dev/null; then
  printf 'hide-main did not hide the SketchyBar arrangement-id for PHL 279C9\n' >&2
  cat "$SKETCHYBAR_TEST_LOG" >&2
  exit 1
fi

main_compact_gap_count="$(grep -F '{ monitor."PHL 279C9" = 8 }' "$tmp_dir/.aerospace.toml" | wc -l | tr -d ' ')"
if [ "$main_compact_gap_count" -lt 4 ]; then
  printf 'hide-main did not compact all outer gaps for PHL 279C9\n' >&2
  sed -n '/^\[gaps\]/,/^\[/p' "$tmp_dir/.aerospace.toml" >&2
  exit 1
fi

printf 'aerospace_workflow_smoke.sh: ok\n'
