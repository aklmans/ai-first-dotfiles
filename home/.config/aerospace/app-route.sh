#!/usr/bin/env bash
set -euo pipefail

# Focus-first editor for app-routes.conf. Every mutation is exact-match data,
# backed up before replacement, rendered into AeroSpace TOML, then reloaded.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEROSPACE="${AEROSPACE:-$(command -v aerospace 2>/dev/null || printf '/opt/homebrew/bin/aerospace')}"
APP_ROUTES_FILE="${APP_ROUTES_FILE:-$SCRIPT_DIR/app-routes.conf}"
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

Direct commands:
  set <id|name> <value> <target|current> <follow|prefer|fixed> [layout]
  remove <id|name> <value>
  list

When layout is omitted, focus-first commands preserve the focused window's
current tiling/floating state. Every change creates an app-routes.conf backup.
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

list_routes() {
  ensure_routes_file
  printf '%-6s %-38s %-14s %-8s %s\n' MATCH APP TARGET POLICY LAYOUT
  /usr/bin/awk -F '|' '
    $1 ~ /^(id|name)$/ && NF == 5 {
      printf "%-6s %-38s %-14s %-8s %s\n", $1, $2, $3, $4, $5
    }
    $1 ~ /^(id|name)$/ && NF == 4 {
      policy = ($3 == "current" ? "follow" : ($3 == "-" ? "inherit" : "fixed"))
      printf "%-6s %-38s %-14s %-8s %s\n", $1, $2, $3, policy, $4
    }
  ' "$APP_ROUTES_FILE"
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
  help|-h|--help)
    usage
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command_name" >&2
    usage >&2
    exit 64
    ;;
esac
