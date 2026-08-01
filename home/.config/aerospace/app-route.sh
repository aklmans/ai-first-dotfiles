#!/usr/bin/env bash
set -euo pipefail

# Focus-first editor for app-routes.conf. Every mutation is exact-match data,
# backed up before replacement, rendered into AeroSpace TOML, then reloaded.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEROSPACE="${AEROSPACE:-$(command -v aerospace 2>/dev/null || printf '/opt/homebrew/bin/aerospace')}"
APP_ROUTES_FILE="${APP_ROUTES_FILE:-$SCRIPT_DIR/app-routes.conf}"
CAPTURED_ROUTES_FILE="${AI_FIRST_CAPTURED_ROUTES_FILE:-$HOME/.config/ai-first/captured-routes.conf}"
RENDER_APP_RULES="${RENDER_APP_RULES:-$SCRIPT_DIR/render-app-rules.sh}"
AEROSPACE_CONFIG_PATH="${AEROSPACE_CONFIG_PATH:-$HOME/.aerospace.toml}"
APP_ROUTE_NOTIFY="${APP_ROUTE_NOTIFY:-1}"

usage() {
  cat <<'EOF'
Usage: app-route.sh <command> [arguments]

Focus-first commands:
  bind-here [tiling|floating|keep]
      Pin the focused app to the focused workspace.
  follow [tiling|floating|keep]
      Keep new windows for the focused app where they are opened.
  prefer <role|workspace> [tiling|floating|keep]
      Prefer a semantic role or workspace for new windows without reset enforcement.
  forget
      Remove the focused app's custom rule and return to shipped defaults.
  capture-current [--policy prefer|fixed|follow] [--layout preserve|keep] [--apply]
      Read the desktop you arranged, propose exact local routes, and optionally
      save them as a lower-priority captured layer. Preview is the default.

Direct commands:
  set <id|name> <value> <target|current> <follow|prefer|fixed> [layout]
  remove <id|name> <value>
  list

When layout is omitted, focus-first commands preserve the focused window's
current tiling/floating state. Every change creates an app-routes.conf backup.
Captured suggestions never replace handwritten app-routes.conf records.
EOF
}

notify() {
  local message="$1"
  printf '%s\n' "$message"
  [ "$APP_ROUTE_NOTIFY" = "1" ] || return 0
  command -v osascript >/dev/null 2>&1 || return 0
  osascript \
    -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title "AeroSpace app route"' \
    -e 'end run' \
    "$message" >/dev/null 2>&1 || true
}

require_aerospace() {
  if [ ! -x "$AEROSPACE" ]; then
    printf 'AeroSpace CLI not found: %s\n' "$AEROSPACE" >&2
    exit 69
  fi
}

focus_route_identity() {
  local line id_field

  require_aerospace
  line="$(
    "$AEROSPACE" list-windows --focused \
      --format 'x%{app-bundle-id}%{tab}%{app-name}%{tab}%{workspace}%{tab}%{window-layout}' \
      2>/dev/null | /usr/bin/head -n 1
  )"
  if [ -z "$line" ]; then
    printf 'No focused AeroSpace window. Focus an app window and try again.\n' >&2
    exit 65
  fi

  IFS=$'\t' read -r id_field FOCUSED_APP_NAME FOCUSED_WORKSPACE FOCUSED_LAYOUT <<<"$line"
  FOCUSED_APP_ID="${id_field#x}"

  if [ -n "$FOCUSED_APP_ID" ]; then
    FOCUSED_MATCH_KIND='id'
    FOCUSED_MATCH_VALUE="$FOCUSED_APP_ID"
  elif [ -n "$FOCUSED_APP_NAME" ]; then
    FOCUSED_MATCH_KIND='name'
    FOCUSED_MATCH_VALUE="$FOCUSED_APP_NAME"
  else
    printf 'The focused window has neither a bundle id nor an app name.\n' >&2
    exit 65
  fi

  case "$FOCUSED_LAYOUT" in
    tiling|floating) ;;
    *) FOCUSED_LAYOUT='-' ;;
  esac
}

validate_match() {
  local kind="$1" value="$2"
  case "$kind" in id|name) ;; *) printf 'Match must be id or name.\n' >&2; exit 64 ;; esac
  case "$value" in ''|*'|'*|*$'\n'*) printf 'App match must be one line without |.\n' >&2; exit 64 ;; esac
}

validate_target() {
  local target="$1" resolved
  [ "$target" = 'current' ] && return 0
  [ -n "$target" ] || { printf 'Target must be a workspace role, configured workspace, or current.\n' >&2; exit 64; }

  if [ -r "$SCRIPT_DIR/lib/layout.sh" ]; then
    # shellcheck source=lib/layout.sh
    source "$SCRIPT_DIR/lib/layout.sh"
    if ! resolved="$(aerospace_layout_resolve_route_target "$target" 2>/dev/null)"; then
      printf 'Unknown target %s. Workspaces: %s; roles: %s\n' \
        "$target" "$(aerospace_layout_workspaces)" \
        "$(aerospace_layout_semantic_roles | tr '\n' ' ')" >&2
      exit 64
    fi
  fi
}

validate_policy() {
  local target="$1" policy="$2"
  case "$policy" in follow|prefer|fixed) ;; *) printf 'Policy must be follow, prefer, or fixed.\n' >&2; exit 64 ;; esac
  if [ "$policy" = 'follow' ] && [ "$target" != 'current' ]; then
    printf 'follow policy requires the current target.\n' >&2
    exit 64
  fi
  if [ "$policy" != 'follow' ] && [ "$target" = 'current' ]; then
    printf '%s policy requires a workspace role or configured workspace.\n' "$policy" >&2
    exit 64
  fi
}

normalize_layout() {
  case "${1:-keep}" in
    tiling|floating) printf '%s\n' "$1" ;;
    keep|-|'') printf '%s\n' '-' ;;
    *) printf 'Layout must be tiling, floating, or keep.\n' >&2; exit 64 ;;
  esac
}

ensure_routes_file() {
  if [ ! -e "$APP_ROUTES_FILE" ]; then
    mkdir -p "$(dirname "$APP_ROUTES_FILE")"
    printf '# match|value|workspace|layout\n' > "$APP_ROUTES_FILE"
  fi
}

apply_route_file() {
  local candidate="$1" description="$2" stamp backup

  ensure_routes_file
  if cmp -s "$candidate" "$APP_ROUTES_FILE"; then
    rm -f "$candidate"
    notify "Unchanged: $description"
    return 0
  fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="$(mktemp "${APP_ROUTES_FILE}.backup-${stamp}.XXXXXX")"
  cp "$APP_ROUTES_FILE" "$backup"
  mv "$candidate" "$APP_ROUTES_FILE"

  if [ -x "$RENDER_APP_RULES" ] && [ -f "$AEROSPACE_CONFIG_PATH" ]; then
    AI_FIRST_APP_ROUTES_FILE="$APP_ROUTES_FILE" \
      "$RENDER_APP_RULES" "$AEROSPACE_CONFIG_PATH"
  else
    printf 'Saved route; render later with %s\n' "$RENDER_APP_RULES" >&2
  fi

  if [ -x "$AEROSPACE" ] && "$AEROSPACE" reload-config --dry-run --no-gui >/dev/null 2>&1; then
    "$AEROSPACE" reload-config >/dev/null 2>&1 || true
  fi
  if [ -f "$HOME/.hammerspoon/init.lua" ] && command -v hs >/dev/null 2>&1; then
    hs -c 'hs.reload()' >/dev/null 2>&1 || true
  fi

  notify "$description (backup: ${backup##*/})"
}

set_route() {
  local kind="$1" value="$2" target="$3" policy="$4" layout="$5"
  local candidate

  validate_match "$kind" "$value"
  validate_target "$target"
  validate_policy "$target" "$policy"
  layout="$(normalize_layout "$layout")"
  ensure_routes_file
  candidate="$(mktemp "${APP_ROUTES_FILE}.XXXXXX")"

  /usr/bin/awk -F '|' -v kind="$kind" -v value="$value" \
    -v record="$kind|$value|$target|$policy|$layout" '
      $1 == kind && $2 == value {
        if (!written) print record
        written = 1
        next
      }
      { print }
      END { if (!written) print record }
    ' "$APP_ROUTES_FILE" > "$candidate"

  apply_route_file "$candidate" "$value → $target ($policy, $layout)"
}

remove_route() {
  local kind="$1" value="$2" candidate
  validate_match "$kind" "$value"
  ensure_routes_file
  candidate="$(mktemp "${APP_ROUTES_FILE}.XXXXXX")"
  /usr/bin/awk -F '|' -v kind="$kind" -v value="$value" \
    '!($1 == kind && $2 == value) { print }' "$APP_ROUTES_FILE" > "$candidate"
  apply_route_file "$candidate" "$value → shipped default"
}

# The app value goes last. printf pads by bytes, so `微信` inside a `%-38s`
# counts as six and drags every column after it out of line; keeping the one
# field that can hold wide characters at the end of the row means only ASCII
# gets padded.
list_routes() {
  ensure_routes_file
  printf '%-6s %-14s %-8s %-8s %s\n' MATCH TARGET POLICY LAYOUT APP
  /usr/bin/awk -F '|' '
    $1 ~ /^(id|name)$/ && NF == 5 {
      printf "%-6s %-14s %-8s %-8s %s\n", $1, $3, $4, $5, $2
    }
    $1 ~ /^(id|name)$/ && NF == 4 {
      policy = ($3 == "current" ? "follow" : ($3 == "-" ? "inherit" : "fixed"))
      printf "%-6s %-14s %-8s %-8s %s\n", $1, $3, policy, $4, $2
    }
  ' "$APP_ROUTES_FILE"
}

capture_role_for_app_workspace() {
  local app_id="$1" app_name="$2" workspace="$3" candidates='' role resolved

  case "$app_id" in
    com.apple.Terminal|dev.warp.Warp-Stable|fun.tw93.kaku) candidates='terminal' ;;
    com.jetbrains.*|com.google.android.studio|com.microsoft.VSCode|com.microsoft.VSCodeInsiders|com.todesktop.230313mzl4w4u92|com.sublimetext.4) candidates='development focus' ;;
    com.openai.codex|com.openai.chat|com.openai.atlas) candidates='ai support' ;;
    company.thebrowser.dia) candidates='research web' ;;
    com.apple.Safari|com.google.Chrome|com.microsoft.edgemac|company.thebrowser.Browser|org.mozilla.firefox) candidates='web research' ;;
    com.tencent.*|com.alibaba.DingTalkMac|com.electron.lark|com.hnc.Discord|com.microsoft.teams2|com.tinyspeck.slackmacgap|us.zoom.xos) candidates='communication stage' ;;
    md.obsidian|abnerworks.Typora|com.tw93.miaoyan|org.ozrey.markdown|org.zrey.markeditor2.x) candidates='notes' ;;
    com.obsproject.obs-studio) candidates='broadcast stage' ;;
    com.techsmith.camtasia|com.TechSmith.Snagit) candidates='stage broadcast' ;;
    com.spotify.client|com.bilibili.bilibiliPC) candidates='media' ;;
  esac

  case "$app_name" in
    GoLand|IntelliJ\ IDEA*|WebStorm|PhpStorm|RustRover|PyCharm|CLion|DataGrip|Rider|Android\ Studio) candidates="${candidates:-development focus}" ;;
    OBS|OBS\ Studio) candidates="${candidates:-broadcast stage}" ;;
  esac

  if [ -r "$SCRIPT_DIR/lib/layout.sh" ]; then
    # shellcheck source=lib/layout.sh
    source "$SCRIPT_DIR/lib/layout.sh"
    for role in $candidates; do
      resolved="$(aerospace_layout_workspace_for_semantic_role "$role" 2>/dev/null || true)"
      if [ "$resolved" = "$workspace" ]; then
        printf '%s\n' "$role"
        return 0
      fi
    done
  fi

  printf '%s\n' "$workspace"
}

apply_captured_route_file() {
  local candidate="$1" description="$2" stamp backup=''

  if [ -L "$CAPTURED_ROUTES_FILE" ]; then
    printf 'Refusing to replace symlink: %s\n' "$CAPTURED_ROUTES_FILE" >&2
    return 1
  fi
  mkdir -p "$(dirname "$CAPTURED_ROUTES_FILE")"
  if cmp -s "$candidate" "$CAPTURED_ROUTES_FILE" 2>/dev/null; then
    rm -f "$candidate"
    notify "Unchanged: $description"
    return 0
  fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  if [ -e "$CAPTURED_ROUTES_FILE" ]; then
    backup="$(mktemp "${CAPTURED_ROUTES_FILE}.backup-${stamp}.XXXXXX")"
    cp "$CAPTURED_ROUTES_FILE" "$backup"
  fi
  mv "$candidate" "$CAPTURED_ROUTES_FILE"

  if [ -x "$RENDER_APP_RULES" ] && [ -f "$AEROSPACE_CONFIG_PATH" ]; then
    AI_FIRST_APP_ROUTES_FILE="$APP_ROUTES_FILE" \
      AI_FIRST_CAPTURED_ROUTES_FILE="$CAPTURED_ROUTES_FILE" \
      "$RENDER_APP_RULES" "$AEROSPACE_CONFIG_PATH"
  else
    printf 'Saved captured routes; render later with %s\n' "$RENDER_APP_RULES" >&2
  fi

  if [ -x "$AEROSPACE" ] && "$AEROSPACE" reload-config --dry-run --no-gui >/dev/null 2>&1; then
    "$AEROSPACE" reload-config >/dev/null 2>&1 || true
  fi
  if [ -f "$HOME/.hammerspoon/init.lua" ] && command -v hs >/dev/null 2>&1; then
    hs -c 'hs.reload()' >/dev/null 2>&1 || true
  fi

  if [ -n "$backup" ]; then
    notify "$description (backup: ${backup##*/})"
  else
    notify "$description"
  fi
}

capture_current_routes() {
  local apply=0 single_policy='prefer' layout_mode='preserve'
  local windows_file='' owned_windows=0 aggregated candidate user_file
  local dropped_file dropped=0
  local kind value app_name workspace captured_layout target policy count=0

  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --apply) apply=1 ;;
      --policy)
        [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
        single_policy="$2"; shift
        ;;
      --layout)
        [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
        layout_mode="$2"; shift
        ;;
      -h|--help) usage; return 0 ;;
      *) printf 'Unknown capture option: %s\n' "$1" >&2; exit 64 ;;
    esac
    shift
  done
  case "$single_policy" in follow|prefer|fixed) ;; *) printf 'Capture policy must be follow, prefer, or fixed.\n' >&2; exit 64 ;; esac
  case "$layout_mode" in preserve|keep) ;; *) printf 'Capture layout must be preserve or keep.\n' >&2; exit 64 ;; esac

  if [ -n "${AEROSPACE_CAPTURE_WINDOWS_FILE:-}" ]; then
    windows_file="$AEROSPACE_CAPTURE_WINDOWS_FILE"
    [ -r "$windows_file" ] || { printf 'Capture fixture is unreadable: %s\n' "$windows_file" >&2; exit 66; }
  else
    require_aerospace
    windows_file="$(mktemp "${TMPDIR:-/tmp}/aerospace-capture-windows.XXXXXX")"
    owned_windows=1
    "$AEROSPACE" list-windows --all \
      --format 'x%{app-bundle-id}%{tab}%{app-name}%{tab}%{workspace}%{tab}%{window-layout}' \
      >"$windows_file" 2>/dev/null || true
  fi

  aggregated="$(mktemp "${TMPDIR:-/tmp}/aerospace-capture-aggregated.XXXXXX")"
  candidate="$(mktemp "${TMPDIR:-/tmp}/aerospace-captured-routes.XXXXXX")"
  dropped_file="$(mktemp "${TMPDIR:-/tmp}/aerospace-capture-dropped.XXXXXX")"
  user_file="$APP_ROUTES_FILE"
  [ -r "$user_file" ] || user_file='/dev/null'

  # The filter below is load-bearing: an app name holding `|` or a newline would
  # write a route file that no longer parses as one record per line, and a
  # workspace name outside [A-Za-z0-9_-] would render an AeroSpace command that
  # cannot run. What it must not do is drop those windows in silence, so the
  # count comes back out through a file and is reported with the preview.
  /usr/bin/awk -F '\t' -v user_routes="$user_file" -v drop_file="$dropped_file" '
    BEGIN {
      dropped = 0
      while ((getline line < user_routes) > 0) {
        split(line, fields, "|")
        if (fields[1] == "id" || fields[1] == "name") user[fields[1] SUBSEP fields[2]] = 1
      }
      close(user_routes)
    }
    {
      id=$1; sub(/^x/, "", id)
      name=$2; workspace=$3; layout=$4
      if (id == "" && name == "") { dropped++; next }
      if (name ~ /[|\r\n]/ || id ~ /[|\r\n]/ || workspace !~ /^[A-Za-z0-9_-]+$/) { dropped++; next }
      kind=(id != "" ? "id" : "name")
      value=(id != "" ? id : name)
      key=kind SUBSEP value
      if (user[key]) next
      if (!seen_workspace[key SUBSEP workspace]++) distinct[key]++
      if (!(key in first_workspace)) first_workspace[key]=workspace
      app_name[key]=name
      total[key]++
      if (layout == "floating") floating[key]++
      if (layout == "tiling") tiling[key]++
    }
    END {
      for (key in total) {
        split(key, pair, SUBSEP)
        layout="-"
        if (floating[key] == total[key]) layout="floating"
        else if (tiling[key] == total[key]) layout="tiling"
        workspace=(distinct[key] > 1 ? "current" : first_workspace[key])
        printf "%s|%s|%s|%s|%s\n", pair[1], pair[2], app_name[key], workspace, layout
      }
      printf "%s\n", dropped > drop_file
      close(drop_file)
    }
  ' "$windows_file" | LC_ALL=C sort >"$aggregated"
  dropped="$(cat "$dropped_file" 2>/dev/null || printf '0')"
  case "$dropped" in ''|*[!0-9]*) dropped=0 ;; esac
  rm -f "$dropped_file"

  {
    printf '# Generated locally by app-route.sh capture-current.\n'
    printf '# Handwritten app-routes.conf records always have higher priority.\n'
    printf '# match|value|target|policy|layout\n'
    while IFS='|' read -r kind value app_name workspace captured_layout rest; do
      [ -z "${rest:-}" ] || continue
      if [ "$workspace" = 'current' ] || [ "$single_policy" = 'follow' ]; then
        target='current'
        policy='follow'
      else
        if [ -r "$SCRIPT_DIR/lib/layout.sh" ]; then
          # shellcheck source=lib/layout.sh
          source "$SCRIPT_DIR/lib/layout.sh"
        fi
        if type aerospace_layout_workspace_is_configured >/dev/null 2>&1 && \
           ! aerospace_layout_workspace_is_configured "$workspace"; then
          # The window may belong to an unmanaged temporary workspace. Capturing
          # that number as a target would produce invalid data, so keep it local.
          target='current'
          policy='follow'
        else
          target="$(capture_role_for_app_workspace "$value" "$app_name" "$workspace")"
          policy="$single_policy"
        fi
      fi
      [ "$layout_mode" = 'preserve' ] || captured_layout='-'
      printf '%s|%s|%s|%s|%s\n' "$kind" "$value" "$target" "$policy" "$captured_layout"
      count=$((count + 1))
    done <"$aggregated"
  } >"$candidate"

  [ "$owned_windows" -eq 0 ] || rm -f "$windows_file"
  rm -f "$aggregated"

  printf 'Captured route proposal (%s app(s))\n\n' "$count"
  printf '  %-5s %-14s %-7s %-8s %s\n' MATCH TARGET POLICY LAYOUT APP
  /usr/bin/awk -F '|' '$1 == "id" || $1 == "name" {
    printf "  %-5s %-14s %-7s %-8s %s\n", $1, $3, $4, $5, $2
  }' "$candidate"
  printf '\nThis is a one-time local snapshot; no background tracking was enabled.\n'
  printf 'Handwritten routes in %s were skipped.\n' "$APP_ROUTES_FILE"
  if [ "$dropped" -gt 0 ]; then
    printf '%s window(s) ignored: unusable app name or workspace.\n' "$dropped"
  fi

  if [ "$apply" -eq 0 ]; then
    rm -f "$candidate"
    printf 'Preview only. Re-run with --apply to save %s.\n' "$CAPTURED_ROUTES_FILE"
    return 0
  fi
  if [ "$count" -eq 0 ]; then
    rm -f "$candidate"
    printf 'Nothing to apply.\n'
    return 0
  fi
  apply_captured_route_file "$candidate" "Captured $count app route(s) from the current desktop"
}

command_name="${1:-help}"
case "$command_name" in
  bind-here)
    focus_route_identity
    set_route "$FOCUSED_MATCH_KIND" "$FOCUSED_MATCH_VALUE" "$FOCUSED_WORKSPACE" fixed \
      "${2:-$FOCUSED_LAYOUT}"
    ;;
  follow)
    focus_route_identity
    set_route "$FOCUSED_MATCH_KIND" "$FOCUSED_MATCH_VALUE" current follow \
      "${2:-$FOCUSED_LAYOUT}"
    ;;
  prefer)
    [ "$#" -ge 2 ] || { usage >&2; exit 64; }
    focus_route_identity
    set_route "$FOCUSED_MATCH_KIND" "$FOCUSED_MATCH_VALUE" "$2" prefer \
      "${3:-$FOCUSED_LAYOUT}"
    ;;
  forget)
    focus_route_identity
    remove_route "$FOCUSED_MATCH_KIND" "$FOCUSED_MATCH_VALUE"
    ;;
  set)
    [ "$#" -ge 5 ] || { usage >&2; exit 64; }
    set_route "$2" "$3" "$4" "$5" "${6:-keep}"
    ;;
  remove)
    [ "$#" -eq 3 ] || { usage >&2; exit 64; }
    remove_route "$2" "$3"
    ;;
  list)
    list_routes
    ;;
  capture-current)
    capture_current_routes "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command_name" >&2
    usage >&2
    exit 64
    ;;
esac
