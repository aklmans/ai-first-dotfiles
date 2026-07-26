#!/usr/bin/env bash
set -euo pipefail

VERSION="2.3.5"

# Configuration
home_dir="${HOME}"
config_dir="${AI_ROUTER_HOME:-$home_dir/.config/ai-router}"
config_json="$config_dir/config.json"
prompts_dir="$config_dir/prompts"
snippets_dir="$config_dir/snippets"
providers_dir="$config_dir/providers"
catalogs_dir="$config_dir/catalogs"
exports_dir="$config_dir/exports"
cache_dir="$config_dir/cache"
state_dir="$config_dir/state"
logs_dir="$config_dir/logs"
errors_dir="$logs_dir/errors"
lib_dir="$config_dir/lib"
router_tools="$lib_dir/router_tools.py"
last_output="$cache_dir/last-output.md"
last_error="$errors_dir/latest.log"
selection_cache="$cache_dir/selection.txt"
selection_meta="$cache_dir/selection-meta.env"
events_log="$logs_dir/events.jsonl"
usage_state="$state_dir/usage.json"
favorites_state="$state_dir/favorites.json"

# Tunable parameters
selection_copy_delay="${AI_ROUTER_SELECTION_COPY_DELAY:-0.28}"
selection_attempts="${AI_ROUTER_SELECTION_ATTEMPTS:-2}"
selection_verify_delay="${AI_ROUTER_SELECTION_VERIFY_DELAY:-0.05}"
selection_polling="${AI_ROUTER_SELECTION_POLLING:-1}"
selection_poll_interval="${AI_ROUTER_SELECTION_POLL_INTERVAL:-0.03}"
selection_poll_count="${AI_ROUTER_SELECTION_POLL_COUNT:-10}"
selection_strict="${AI_ROUTER_SELECTION_STRICT:-0}"
selection_backend="${AI_ROUTER_SELECTION_BACKEND:-applescript}"
log_retention_days="${AI_ROUTER_LOG_RETENTION_DAYS:-30}"
max_log_size="${AI_ROUTER_MAX_LOG_SIZE:-10485760}"
provider_health_cache_ttl="${AI_ROUTER_PROVIDER_HEALTH_CACHE_TTL:-60}"
provider_timeout_seconds="${AI_ROUTER_PROVIDER_TIMEOUT_SECONDS:-60}"
debug_full_log="${AI_ROUTER_DEBUG_FULL_LOG:-0}"

ensure_dirs() {
  mkdir -p "$prompts_dir" "$snippets_dir" "$providers_dir" "$catalogs_dir" "$exports_dir" "$cache_dir" "$state_dir" "$logs_dir" "$errors_dir" "$lib_dir"
  chmod 700 "$cache_dir" "$state_dir" "$logs_dir" "$errors_dir"
}

check_dependencies() {
  local missing=()
  for cmd in python3 osascript pbcopy pbpaste; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    printf 'AI Router: missing dependencies: %s\n' "${missing[*]}" >&2
    exit 69
  fi
  if [ ! -f "$router_tools" ]; then
    printf 'AI Router: missing router_tools.py at %s\n' "$router_tools" >&2
    exit 69
  fi
}

sanitize_error_text() {
  local error="$1"
  printf '%s' "$error" | python3 "$router_tools" sanitize
}

rotate_logs() {
  if [ ! -f "$events_log" ]; then
    return
  fi

  local log_size
  log_size="$(stat -f%z "$events_log" 2>/dev/null || stat -c%s "$events_log" 2>/dev/null || echo 0)"

  if [ "$log_size" -gt "$max_log_size" ]; then
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    mv "$events_log" "$events_log.$timestamp"
    gzip "$events_log.$timestamp" 2>/dev/null || true
  fi

  find "$errors_dir" -type f -name "*.log" -mtime +"$log_retention_days" -delete 2>/dev/null || true
  find "$logs_dir" -type f -name "events.jsonl.*" -mtime +"$log_retention_days" -delete 2>/dev/null || true
}

usage() {
  printf '%s\n' "AI Router v$VERSION"
  printf '%s\n' "Usage:"
  printf '%s\n' "  ai-router.sh render <action>"
  printf '%s\n' "  ai-router.sh run <action>"
  printf '%s\n' "  ai-router.sh palette"
  printf '%s\n' "  ai-router.sh agent-menu"
  printf '%s\n' "  ai-router.sh agent codex|claude|junie|gemini|kimi|warp-agent"
  printf '%s\n' "  ai-router.sh agent-run codex|claude"
  printf '%s\n' "  ai-router.sh list prompts|snippets|skills|plugins|providers|agents"
  printf '%s\n' "  ai-router.sh index"
  printf '%s\n' "  ai-router.sh export-snippets raycast|generic|all"
  printf '%s\n' "  ai-router.sh snippet <name>"
  printf '%s\n' "  ai-router.sh skill <name-or-path>"
  printf '%s\n' "  ai-router.sh plugin <name-or-path>"
  printf '%s\n' "  ai-router.sh favorite list|add|remove|toggle <kind> <value> [title]"
  printf '%s\n' "  ai-router.sh tool index|provider-status|last-output|last-error|config|prompts|snippets|logs"
  printf '%s\n' "  ai-router.sh version"
}

now_ms() {
  python3 "$router_tools" now-ms
}

write_selection_meta() {
  local source="$1"
  local duration_ms="$2"
  local attempts="$3"
  local status="$4"
  ensure_dirs
  {
    printf 'source=%s\n' "$source"
    printf 'duration_ms=%s\n' "$duration_ms"
    printf 'attempts=%s\n' "$attempts"
    printf 'status=%s\n' "$status"
  } > "$selection_meta"
}

selection_meta_field() {
  local field="$1"
  awk -F= -v key="$field" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$selection_meta" 2>/dev/null || true
}

notify() {
  local title="$1"
  local message="$2"
  /usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
}

frontmost_app() {
  /usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true
}

window_title() {
  /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  try
    return name of front window of frontApp
  on error
    return ""
  end try
end tell
APPLESCRIPT
}

clipboard_copy() {
  LC_ALL= LC_CTYPE=en_US.UTF-8 LANG=en_US.UTF-8 /usr/bin/pbcopy
}

clipboard_paste() {
  LC_ALL= LC_CTYPE=en_US.UTF-8 LANG=en_US.UTF-8 /usr/bin/pbpaste
}

copy_text_to_clipboard() {
  local text="$1"

  if printf '%s' "$text" | clipboard_copy 2>/dev/null; then
    return 0
  fi

  AI_ROUTER_CLIPBOARD_TEXT="$text" /usr/bin/osascript <<'APPLESCRIPT' >/dev/null 2>&1 && return 0
set the clipboard to (system attribute "AI_ROUTER_CLIPBOARD_TEXT")
APPLESCRIPT

  return 1
}

read_selection_applescript() {
  /usr/bin/osascript - "$selection_attempts" "$selection_poll_count" "$selection_poll_interval" "$selection_copy_delay" "$selection_verify_delay" "$selection_polling" <<'APPLESCRIPT'
on run argv
  set maxAttempts to item 1 of argv as integer
  set pollCount to item 2 of argv as integer
  set pollInterval to item 3 of argv as real
  set copyDelay to item 4 of argv as real
  set verifyDelay to item 5 of argv as real
  set pollingEnabled to item 6 of argv is "1"
  set savedClipboard to missing value
  set selectedText to ""
  set attemptsUsed to 0

  try
    set savedClipboard to the clipboard
  end try

  repeat with attempt from 1 to maxAttempts
    set attemptsUsed to attempt
    set sentinel to "__AI_ROUTER_SELECTION_SENTINEL_" & (random number from 100000 to 999999) & "_" & attempt & "__"
    set the clipboard to sentinel
    tell application "System Events" to keystroke "c" using {command down}

    if pollingEnabled then
      repeat with poll from 1 to pollCount
        delay pollInterval
        try
          set candidate to the clipboard as text
        on error
          set candidate to ""
        end try
        if candidate is not sentinel and candidate is not "" then
          set selectedText to candidate
          exit repeat
        end if
      end repeat
    else
      delay copyDelay
      try
        set candidate to the clipboard as text
      on error
        set candidate to ""
      end try
      if candidate is not sentinel and candidate is not "" then
        set selectedText to candidate
      end if
    end if

    if selectedText is not "" then exit repeat
    delay verifyDelay
  end repeat

  if savedClipboard is not missing value then
    set the clipboard to savedClipboard
  end if

  return (attemptsUsed as text) & linefeed & selectedText
end run
APPLESCRIPT
}

read_selection() {
  if [ -n "${AI_ROUTER_SELECTION:-}" ]; then
    write_selection_meta "env" "0" "0" "ok"
    printf '%s' "$AI_ROUTER_SELECTION"
    return
  fi

  local saved_clipboard selected sentinel attempt poll start_ms end_ms duration_ms attempts_used raw
  start_ms="$(now_ms)"

  if [ "$selection_backend" = "applescript" ]; then
    raw="$(read_selection_applescript 2>/dev/null || true)"
    if [ -n "$raw" ]; then
      attempts_used="${raw%%$'\n'*}"
      selected="${raw#*$'\n'}"
      [ "$selected" != "$raw" ] || selected=""
      end_ms="$(now_ms)"
      duration_ms=$((end_ms - start_ms))
      if [ -n "$selected" ]; then
        write_selection_meta "selection" "$duration_ms" "$attempts_used" "ok"
      else
        write_selection_meta "empty" "$duration_ms" "$attempts_used" "fallback"
      fi
      printf '%s' "$selected"
      return
    fi
  fi

  saved_clipboard="$(clipboard_paste 2>/dev/null || true)"
  sentinel="__AI_ROUTER_SELECTION_SENTINEL_$$_$(now_ms)__"
  selected=""
  attempts_used=0

  for ((attempt = 1; attempt <= selection_attempts; attempt++)); do
    attempts_used="$attempt"
    printf '%s' "$sentinel" | clipboard_copy 2>/dev/null || true
    /usr/bin/osascript -e 'tell application "System Events" to keystroke "c" using {command down}' >/dev/null 2>&1 || true

    if [ "$selection_polling" = "1" ]; then
      for ((poll = 1; poll <= selection_poll_count; poll++)); do
        sleep "$selection_poll_interval"
        selected="$(clipboard_paste 2>/dev/null || true)"
        if [ "$selected" != "$sentinel" ] && [ -n "$selected" ]; then
          break 2
        fi
      done
    else
      sleep "$selection_copy_delay"
      selected="$(clipboard_paste 2>/dev/null || true)"
    fi

    if [ "$selected" != "$sentinel" ] && [ -n "$selected" ]; then
      break
    fi

    selected=""
    sleep "$selection_verify_delay"
  done

  printf '%s' "$saved_clipboard" | clipboard_copy 2>/dev/null || true

  if [ "$selected" = "$sentinel" ]; then
    selected=""
  fi

  end_ms="$(now_ms)"
  duration_ms=$((end_ms - start_ms))
  if [ -n "$selected" ]; then
    write_selection_meta "selection" "$duration_ms" "$attempts_used" "ok"
  else
    write_selection_meta "empty" "$duration_ms" "$attempts_used" "fallback"
  fi

  printf '%s' "$selected"
}

parse_frontmatter_field() {
  local path="$1"
  local field="$2"
  python3 "$router_tools" field "$path" "$field"
}

prompt_body() {
  local path="$1"
  python3 "$router_tools" body "$path"
}

render_template() {
  local template_path="$1"
  local action="$2"
  local selection="$3"
  local clipboard="$4"
  local app_name="$5"
  local title="$6"

  AI_ROUTER_SELECTION_TEXT="$selection" \
  AI_ROUTER_CLIPBOARD_TEXT="$clipboard" \
  AI_ROUTER_FRONTMOST_APP="$app_name" \
  AI_ROUTER_WINDOW_TITLE="$title" \
  AI_ROUTER_ACTION="$action" \
  AI_ROUTER_DATE="$(date +%F)" \
  python3 "$router_tools" render "$template_path"
}

validate_id() {
  local value="$1"
  local label="$2"
  if [[ ! "$value" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
    printf 'invalid %s: %s\n' "$label" "$value" >&2
    return 64
  fi
}

prompt_path() {
  validate_id "$1" "prompt id" || return
  printf '%s/%s.md' "$prompts_dir" "$1"
}

snippet_path() {
  validate_id "$1" "snippet id" || return
  printf '%s/%s.md' "$snippets_dir" "$1"
}

new_request_id() {
  printf '%s-%s-%s\n' "$(date +%Y%m%d%H%M%S)" "$$" "$RANDOM"
}

log_event() {
  local action="$1"
  local provider="$2"
  local input_chars="$3"
  local output_chars="$4"
  local duration_ms="$5"
  local status="$6"
  local error="${7:-}"
  local request_id="${8:-$(new_request_id)}"
  local selection_source selection_ms selection_attempt_count

  ensure_dirs
  selection_source="$(selection_meta_field source)"
  selection_ms="$(selection_meta_field duration_ms)"
  selection_attempt_count="$(selection_meta_field attempts)"
  AI_ROUTER_REQUEST_ID="$request_id" \
  AI_ROUTER_EVENT_ACTION="$action" \
  AI_ROUTER_EVENT_PROVIDER="$provider" \
  AI_ROUTER_EVENT_INPUT_CHARS="$input_chars" \
  AI_ROUTER_EVENT_OUTPUT_CHARS="$output_chars" \
  AI_ROUTER_EVENT_DURATION_MS="$duration_ms" \
  AI_ROUTER_EVENT_STATUS="$status" \
  AI_ROUTER_EVENT_ERROR="$error" \
  AI_ROUTER_EVENT_INPUT_SOURCE="${input_source:-}" \
  AI_ROUTER_EVENT_SELECTION_SOURCE="$selection_source" \
  AI_ROUTER_EVENT_SELECTION_MS="$selection_ms" \
  AI_ROUTER_EVENT_SELECTION_ATTEMPTS="$selection_attempt_count" \
  python3 "$router_tools" log-event "$events_log"
}

record_usage() {
  local kind="$1"
  local value="$2"
  local title="${3:-$value}"
  ensure_dirs
  python3 "$router_tools" state-record "$usage_state" "$kind" "$value" "$title" >/dev/null 2>&1 || true
}

favorite_action() {
  local action="$1"
  local kind="${2:-}"
  local value="${3:-}"
  local title="${4:-$value}"
  local result

  ensure_dirs
  case "$action" in
    list)
      python3 "$router_tools" state-favorite "$favorites_state" list
      ;;
    add|remove|toggle)
      [ -n "$kind" ] && [ -n "$value" ] || { usage; return 64; }
      result="$(python3 "$router_tools" state-favorite "$favorites_state" "$action" "$kind" "$value" "$title")"
      notify "AI Router" "Favorite ${result}: $title"
      printf '%s\n' "$result"
      ;;
    *)
      usage
      return 64
      ;;
  esac
}

write_error_log() {
  local request_id="$1"
  local action="$2"
  local provider="$3"
  local error="$4"
  local raw_error="${5:-}"
  local path="$errors_dir/$request_id.log"
  local raw_path="$errors_dir/$request_id.raw.log"

  ensure_dirs
  {
    printf 'request_id: %s\n' "$request_id"
    printf 'action: %s\n' "$action"
    printf 'provider: %s\n\n' "$provider"
    printf '%s\n' "$error"
  } > "$path"

  if [ "$debug_full_log" = "1" ] && [ -n "$raw_error" ] && [ "$raw_error" != "$error" ]; then
    {
      printf 'request_id: %s\n' "$request_id"
      printf 'action: %s\n' "$action"
      printf 'provider: %s\n' "$provider"
      printf 'debug: raw provider error\n\n'
      printf '%s\n' "$raw_error"
    } > "$raw_path"
    chmod 600 "$raw_path" 2>/dev/null || true
  fi

  cp "$path" "$last_error" 2>/dev/null || true
  printf '%s' "$path"
}

short_error() {
  local error="$1"
  printf '%s' "$error" | tr '\r\n' ' ' | cut -c 1-180
}

provider_names() {
  local path name
  for path in "$providers_dir"/*.sh; do
    [ -x "$path" ] || continue
    name="${path##*/}"
    printf '%s\n' "${name%.sh}"
  done
}

# A provider is whatever has an executable adapter in providers/. Whether the
# underlying CLI exists is the adapter's own business, reported via
# --health-check (see provider_healthy). Do not reintroduce a name whitelist
# here: it would make dropping in a new provider script impossible.
provider_available() {
  local provider="$1"
  [ -n "$provider" ] && [ -x "$providers_dir/$provider.sh" ]
}

provider_healthy() {
  local provider="$1"
  local cache_file="$cache_dir/provider-health-$provider"
  local now
  now="$(date +%s)"

  if [ -f "$cache_file" ]; then
    local cached_time cached_status
    read -r cached_time cached_status < "$cache_file" 2>/dev/null || true
    if [ -n "$cached_time" ] && [ -n "$cached_status" ] && [ $((now - cached_time)) -lt "$provider_health_cache_ttl" ]; then
      [ "$cached_status" = "ok" ]
      return
    fi
  fi

  local status="failed"
  if "$providers_dir/$provider.sh" --health-check >/dev/null 2>&1; then
    status="ok"
  fi

  printf '%s %s\n' "$now" "$status" > "$cache_file"
  [ "$status" = "ok" ]
}

choose_provider() {
  local primary="$1"
  shift
  local candidates=("$primary" "$@")

  for provider in "${candidates[@]}"; do
    [ -z "$provider" ] && continue
    if provider_available "$provider" && provider_healthy "$provider"; then
      printf '%s\n' "$provider"
      return 0
    fi
  done

  return 1
}

append_provider_candidate() {
  local candidate="$1"
  candidate="$(printf '%s' "$candidate" | tr -d '[:space:]')"
  [ -n "$candidate" ] || return 0
  validate_id "$candidate" "provider" >/dev/null || return 0

  local existing
  for existing in "${provider_candidates[@]:-}"; do
    [ "$existing" = "$candidate" ] && return 0
  done

  provider_candidates+=("$candidate")
}

append_provider_candidates_csv() {
  local raw="$1"
  local candidate
  raw="${raw//;/,}"
  IFS=',' read -r -a candidates_from_csv <<< "$raw"
  for candidate in "${candidates_from_csv[@]:-}"; do
    append_provider_candidate "$candidate"
  done
}

run_provider_with_timeout() {
  local provider="$1"
  local rendered="$2"
  printf '%s' "$rendered" | python3 "$router_tools" run-provider "$providers_dir/$provider.sh" "$provider_timeout_seconds"
}

write_last_output() {
  ensure_dirs
  local text="$1"
  printf '%s' "$text" > "$last_output"
}

run_action() {
  ensure_dirs
  local action="$1"
  validate_id "$action" "action" || return
  local path
  path="$(prompt_path "$action")"

  if [ ! -f "$path" ]; then
    printf 'prompt not found: %s\n' "$action" >&2
    return 66
  fi

  local start_ms end_ms duration_ms selection clipboard app_name title input_text input_source input_note rendered
  local primary fallback fallback_providers provider output_mode output status output_chars input_chars error
  local prompt_title
  local request_id error_path error_summary sanitized_error
  local provider_status provider_errors provider_attempts provider_exit
  local provider_candidates candidates_from_csv
  request_id="$(new_request_id)"
  start_ms="$(now_ms)"
  selection="$(read_selection)"
  clipboard="$(clipboard_paste 2>/dev/null || true)"
  app_name="$(frontmost_app)"
  title="$(window_title)"

  input_source="selection"
  input_text="$selection"
  if [ -z "$input_text" ]; then
    if [ "$selection_strict" = "1" ]; then
      input_source="empty"
      end_ms="$(now_ms)"
      duration_ms=$((end_ms - start_ms))
      write_last_output "No selected text for action: $action"
      log_event "$action" "input" "0" "0" "$duration_ms" "failed" "no selected text" "$request_id"
      notify "AI Router" "No selected text for $action"
      printf 'no selected text for action: %s\n' "$action" >&2
      return 66
    fi
    input_source="clipboard"
    input_text="$clipboard"
  fi
  if [ -z "$input_text" ]; then
    input_source="empty"
  fi

  input_note=""
  if [ "$input_source" = "clipboard" ]; then
    input_note=" (clipboard input)"
  elif [ "$input_source" = "empty" ]; then
    input_note=" (empty input)"
  fi

  printf '%s' "$selection" > "$selection_cache"

  rendered="$(render_template "$path" "$action" "$input_text" "$clipboard" "$app_name" "$title")"
  primary="$(parse_frontmatter_field "$path" default_provider)"
  fallback="$(parse_frontmatter_field "$path" fallback_provider)"
  fallback_providers="$(parse_frontmatter_field "$path" fallback_providers)"
  output_mode="$(parse_frontmatter_field "$path" output)"
  prompt_title="$(parse_frontmatter_field "$path" title)"
  [ -n "$primary" ] || primary="kimi"
  [ -n "$fallback" ] || fallback="gemini"
  [ -n "$output_mode" ] || output_mode="clipboard"
  [ -n "$prompt_title" ] || prompt_title="$action"

  provider_candidates=()
  append_provider_candidate "$primary"
  append_provider_candidates_csv "$fallback_providers"
  append_provider_candidate "$fallback"

  input_chars="${#input_text}"

  if [ "${AI_ROUTER_DRY_RUN:-0}" = "1" ]; then
    write_last_output "$rendered"
    copy_text_to_clipboard "$rendered" || true
    end_ms="$(now_ms)"
    duration_ms=$((end_ms - start_ms))
    log_event "$action" "dry-run" "$input_chars" "${#rendered}" "$duration_ms" "ok" "" "$request_id"
    notify "AI Router" "Dry run: rendered prompt copied for $action$input_note"
    printf '%s\n' "$rendered"
    return 0
  fi

  status="ok"
  error=""
  output=""
  provider=""
  provider_status="failed"
  provider_errors=""
  provider_attempts=""
  provider_exit=70

  for provider in "${provider_candidates[@]:-}"; do
    if [ -n "$provider_attempts" ]; then
      provider_attempts="$provider_attempts,$provider"
    else
      provider_attempts="$provider"
    fi

    if ! provider_available "$provider"; then
      provider_errors="${provider_errors}${provider}: unavailable or adapter missing"$'\n'
      provider_exit=69
      continue
    fi

    if ! provider_healthy "$provider"; then
      provider_errors="${provider_errors}${provider}: health check failed"$'\n'
      provider_exit=69
      continue
    fi

    if output="$(run_provider_with_timeout "$provider" "$rendered" 2>&1)"; then
      provider_status="ok"
      break
    else
      provider_exit=$?
    fi

    if [ "$provider_exit" -eq 71 ]; then
      provider_errors="${provider_errors}${provider}: timeout after ${provider_timeout_seconds}s"$'\n'
    else
      provider_errors="${provider_errors}${provider}: ${output}"$'\n'
    fi
  done

  if [ "$provider_status" != "ok" ]; then
    status="failed"
    error="All providers failed for action '$action'. Tried: ${provider_attempts:-none}"$'\n\n'"$provider_errors"
    sanitized_error="$(sanitize_error_text "$error")"
    write_last_output "$sanitized_error"
    copy_text_to_clipboard "$sanitized_error" || true
    error_path="$(write_error_log "$request_id" "$action" "${provider_attempts:-none}" "$sanitized_error" "$error")"
    error_summary="$(short_error "$sanitized_error")"
    end_ms="$(now_ms)"
    duration_ms=$((end_ms - start_ms))
    log_event "$action" "${provider_attempts:-none}" "$input_chars" "${#sanitized_error}" "$duration_ms" "$status" "$sanitized_error" "$request_id"
    notify "AI Router failed" "$action: $error_summary"
    printf '%s\n' "$sanitized_error" >&2
    return "$provider_exit"
  fi

  write_last_output "$output"
  output_chars="${#output}"
  if [ "$output_mode" = "clipboard" ]; then
    copy_text_to_clipboard "$output" || true
    notify "AI Router" "Done: $action with $provider$input_note, copied to clipboard"
  else
    notify "AI Router" "Done: $action with $provider$input_note, saved to last-output.md"
  fi

  record_usage "prompt" "$action" "$prompt_title"
  end_ms="$(now_ms)"
  duration_ms=$((end_ms - start_ms))
  log_event "$action" "$provider" "$input_chars" "$output_chars" "$duration_ms" "$status" "$error" "$request_id"
  printf '%s\n' "$output"
}

render_prompt() {
  ensure_dirs
  local action="$1"
  validate_id "$action" "action" || return
  local path
  path="$(prompt_path "$action")"

  if [ ! -f "$path" ]; then
    printf 'prompt not found: %s\n' "$action" >&2
    return 66
  fi

  local start_ms end_ms duration_ms selection clipboard app_name title input_text input_source input_note rendered input_chars prompt_title
  local request_id
  request_id="$(new_request_id)"
  start_ms="$(now_ms)"
  selection="$(read_selection)"
  clipboard="$(clipboard_paste 2>/dev/null || true)"
  app_name="$(frontmost_app)"
  title="$(window_title)"

  input_source="selection"
  input_text="$selection"
  if [ -z "$input_text" ]; then
    if [ "$selection_strict" = "1" ]; then
      input_source="empty"
      end_ms="$(now_ms)"
      duration_ms=$((end_ms - start_ms))
      write_last_output "No selected text for action: $action"
      log_event "$action" "render" "0" "0" "$duration_ms" "failed" "no selected text" "$request_id"
      notify "AI Router" "No selected text for $action"
      printf 'no selected text for action: %s\n' "$action" >&2
      return 66
    fi
    input_source="clipboard"
    input_text="$clipboard"
  fi
  if [ -z "$input_text" ]; then
    input_source="empty"
  fi

  input_note=""
  if [ "$input_source" = "clipboard" ]; then
    input_note=" (clipboard input)"
  elif [ "$input_source" = "empty" ]; then
    input_note=" (empty input)"
  fi

  printf '%s' "$selection" > "$selection_cache"
  rendered="$(render_template "$path" "$action" "$input_text" "$clipboard" "$app_name" "$title")"
  prompt_title="$(parse_frontmatter_field "$path" title)"
  [ -n "$prompt_title" ] || prompt_title="$action"
  write_last_output "$rendered"
  copy_text_to_clipboard "$rendered" || true

  input_chars="${#input_text}"
  end_ms="$(now_ms)"
  duration_ms=$((end_ms - start_ms))
  log_event "$action" "render" "$input_chars" "${#rendered}" "$duration_ms" "ok" "" "$request_id"
  record_usage "prompt" "$action" "$prompt_title"
  notify "AI Router" "Prompt copied: $action$input_note"
  printf '%s\n' "$rendered"
}

prompt_row() {
  local path="$1"
  local id title description tags
  id="$(parse_frontmatter_field "$path" id)"
  title="$(parse_frontmatter_field "$path" title)"
  description="$(parse_frontmatter_field "$path" description)"
  tags="$(parse_frontmatter_field "$path" tags)"
  [ -n "$id" ] || id="$(basename "$path" .md)"
  [ -n "$title" ] || title="$id"
  printf '%s\t%s\t%s\t%s\n' "$id" "$title" "$description" "$tags"
}

list_prompt_rows() {
  local path
  find "$prompts_dir" -maxdepth 1 -type f -name '*.md' -print | sort | while IFS= read -r path; do
    prompt_row "$path"
  done
}

snippet_row() {
  local path="$1"
  local name title first_line
  name="$(basename "$path" .md)"
  title="$(sed -n '1s/^# *//p' "$path" | tr '\t' ' ')"
  first_line="$(awk 'NR > 1 && NR <= 8 && NF { sub(/^[[:space:]]+/, ""); print; exit }' "$path" | tr '\t' ' ')"
  [ -n "$title" ] || title="$name"
  printf '%s\t%s\t%s\n' "$name" "$title" "$first_line"
}

list_snippet_rows() {
  local path
  find "$snippets_dir" -maxdepth 1 -type f -name '*.md' -print | sort | while IFS= read -r path; do
    snippet_row "$path"
  done
}

skill_paths() {
  local root
  for root in "$home_dir/.codex/skills" "$home_dir/.agents/skills"; do
    if [ -d "$root" ]; then
      find "$root" -maxdepth 3 -name SKILL.md -print
    fi
  done
}

skill_description() {
  local path="$1"
  awk -F': ' '/^description: / { value=$2; gsub(/^"/, "", value); gsub(/"$/, "", value); print value; exit }' "$path" | tr '\t' ' '
}

list_skill_rows() {
  local path name desc
  skill_paths | sort | while IFS= read -r path; do
    name="$(basename "$(dirname "$path")")"
    desc="$(skill_description "$path")"
    printf '%s\t%s\t%s\n' "$name" "$desc" "$path"
  done
}

plugin_paths() {
  for root in "$home_dir/.codex/plugins" "$home_dir/.codex/plugins/cache" "$home_dir/.agents/plugins"; do
    if [ -d "$root" ]; then
      find "$root" -maxdepth 8 -name plugin.json -print
    fi
  done
}

plugin_row() {
  local path="$1"
  python3 "$router_tools" plugin-row "$path"
}

list_plugin_rows() {
  local path
  plugin_paths | sort -u | while IFS= read -r path; do
    plugin_row "$path"
  done
}

find_skill() {
  local query="$1"
  local path name
  if [ -f "$query" ]; then
    printf '%s\n' "$query"
    return 0
  fi

  while IFS= read -r path; do
    name="$(basename "$(dirname "$path")")"
    if [ "$name" = "$query" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done < <(skill_paths)

  return 1
}

find_plugin() {
  local query="$1"
  local path row name
  if [ -f "$query" ]; then
    printf '%s\n' "$query"
    return 0
  fi

  while IFS= read -r path; do
    row="$(plugin_row "$path")"
    name="${row%%	*}"
    if [ "$name" = "$query" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done < <(plugin_paths)

  return 1
}

copy_rendered_snippet() {
  local name="$1"
  validate_id "$name" "snippet id" || return
  local path
  path="$(snippet_path "$name")"
  if [ ! -f "$path" ]; then
    printf 'snippet not found: %s\n' "$name" >&2
    return 66
  fi

  local selection clipboard app_name title rendered
  selection="$(read_selection)"
  clipboard="$(clipboard_paste 2>/dev/null || true)"
  app_name="$(frontmost_app)"
  title="$(window_title)"
  rendered="$(render_template "$path" "$name" "$selection" "$clipboard" "$app_name" "$title")"
  copy_text_to_clipboard "$rendered" || true
  record_usage "snippet" "$name" "$name"
  notify "AI Router" "Snippet copied: $name"
  printf '%s\n' "$rendered"
}

copy_skill() {
  local query="$1"
  local path name desc text
  path="$(find_skill "$query")" || { printf 'skill not found: %s\n' "$query" >&2; return 66; }
  name="$(basename "$(dirname "$path")")"
  desc="$(skill_description "$path")"
  text="$(printf '# Codex Skill: %s\n\nPath: %s\n\nDescription: %s\n' "$name" "$path" "$desc")"
  copy_text_to_clipboard "$text" || true
  record_usage "skill" "$query" "$name"
  notify "AI Router" "Skill copied: $name"
  printf '%s\n' "$text"
}

copy_plugin() {
  local query="$1"
  local path row name desc text
  path="$(find_plugin "$query")" || { printf 'plugin not found: %s\n' "$query" >&2; return 66; }
  row="$(plugin_row "$path")"
  name="$(printf '%s' "$row" | awk -F'\t' '{ print $1 }')"
  desc="$(printf '%s' "$row" | awk -F'\t' '{ print $2 }')"
  text="$(printf '# Codex Plugin: %s\n\nPath: %s\n\nDescription: %s\n' "$name" "$path" "$desc")"
  copy_text_to_clipboard "$text" || true
  record_usage "plugin" "$query" "$name"
  notify "AI Router" "Plugin copied: $name"
  printf '%s\n' "$text"
}

launch_in_warp() {
  local command_text="$1"
  local execute="${2:-0}"

  /usr/bin/osascript - "$command_text" "$execute" <<'APPLESCRIPT'
on run argv
  set commandText to item 1 of argv
  set shouldExecute to item 2 of argv
  set savedClipboard to missing value

  try
    set savedClipboard to the clipboard
  end try

  tell application "Warp" to activate
  delay 0.12

  tell application "System Events"
    keystroke "t" using {command down}
    delay 0.35
  end tell

  set the clipboard to commandText
  tell application "System Events"
    keystroke "v" using {command down}
    delay 0.35
    if shouldExecute is "1" then
      key code 36
    end if
  end tell

  if savedClipboard is not missing value then
    set the clipboard to savedClipboard
  end if
end run
APPLESCRIPT
}

agent_field() {
  local agent="$1"
  local field="$2"
  validate_id "$agent" "agent" || return
  python3 "$router_tools" config-agent-field "$config_json" "$agent" "$field"
}

agent_command() {
  agent_field "$1" command
}

agent_behavior() {
  agent_field "$1" behavior
}

agent_label() {
  agent_field "$1" label
}

run_agent() {
  local agent="$1"
  validate_id "$agent" "agent" || return
  local command_text behavior label
  command_text="$(agent_command "$agent" 2>/dev/null || true)"
  if [ -z "$command_text" ]; then
    printf 'unknown agent: %s\n' "$agent" >&2
    return 64
  fi
  behavior="$(agent_behavior "$agent" 2>/dev/null || true)"
  label="$(agent_label "$agent" 2>/dev/null || true)"

  case "$behavior" in
    open_app)
      case "$agent" in
        codex-app) /usr/bin/open -a "Codex" >/dev/null 2>&1 || codex app >/dev/null 2>&1 || true ;;
        *) /usr/bin/open -a "$label" >/dev/null 2>&1 || true ;;
      esac
      record_usage "agent" "$agent" "${label:-$agent}"
      notify "AI Router" "Opening ${label:-$agent}"
      ;;
    *)
      launch_in_warp "$command_text"
      record_usage "agent" "$agent" "${label:-$agent}"
      notify "AI Router" "Agent command pasted: $agent"
      ;;
  esac
}

run_agent_execute() {
  local agent="$1"
  validate_id "$agent" "agent" || return
  local command_text behavior label
  command_text="$(agent_command "$agent" 2>/dev/null || true)"
  if [ -z "$command_text" ]; then
    printf 'unknown agent: %s\n' "$agent" >&2
    return 64
  fi
  behavior="$(agent_behavior "$agent" 2>/dev/null || true)"
  label="$(agent_label "$agent" 2>/dev/null || true)"

  case "$behavior" in
    open_app)
      case "$agent" in
        codex-app) /usr/bin/open -a "Codex" >/dev/null 2>&1 || codex app >/dev/null 2>&1 || true ;;
        *) /usr/bin/open -a "$label" >/dev/null 2>&1 || true ;;
      esac
      record_usage "agent" "$agent" "${label:-$agent}"
      notify "AI Router" "Opening ${label:-$agent}"
      ;;
    *)
      launch_in_warp "$command_text" "1"
      record_usage "agent" "$agent" "${label:-$agent}"
      notify "AI Router" "Agent started: $agent"
      ;;
  esac
}

agent_menu() {
  python3 "$router_tools" config-agent-menu "$config_json"
}

palette_data_dynamic() {
  local id title desc tags name path
  while IFS=$'\t' read -r id title desc tags; do
    printf 'prompt:%s\tPrompt: %s\t%s\tprompt\t%s\n' "$id" "$title" "$desc" "$id"
  done < <(list_prompt_rows)

  while IFS=$'\t' read -r name title desc; do
    printf 'snippet:%s\tSnippet: %s\t%s\tsnippet\t%s\n' "$name" "$title" "$desc" "$name"
  done < <(list_snippet_rows)

  agent_menu

  while IFS=$'\t' read -r name desc path; do
    printf 'skill:%s\tSkill: %s\t%s\tskill\t%s\n' "$name" "$name" "$desc" "$path"
  done < <(list_skill_rows)

  while IFS=$'\t' read -r name desc path; do
    printf 'plugin:%s\tPlugin: %s\t%s\tplugin\t%s\n' "$name" "$name" "$desc" "$path"
  done < <(list_plugin_rows)

  printf 'tool:index\tTool: Rebuild Catalog Index\t生成 prompts/snippets/skills/plugins 索引\ttool\tindex\n'
  printf 'tool:provider-status\tTool: Show Provider Status\t检测 Kimi/Gemini/Codex/Claude/Junie\ttool\tprovider-status\n'
  printf 'tool:last-output\tTool: Open Last Output\t打开 cache/last-output.md\ttool\tlast-output\n'
  printf 'tool:last-error\tTool: Open Last Error\t打开最近一次错误日志\ttool\tlast-error\n'
  printf 'tool:config\tTool: Open AI Router Config\t打开 ~/.config/ai-router\ttool\tconfig\n'
  printf 'tool:prompts\tTool: Open Prompt Folder\t打开 prompts 目录\ttool\tprompts\n'
  printf 'tool:snippets\tTool: Open Snippet Folder\t打开 snippets 目录\ttool\tsnippets\n'
  printf 'tool:logs\tTool: Open Logs\t打开 logs 目录\ttool\tlogs\n'
}

palette_data() {
  local palette_cache="$catalogs_dir/palette.json"

  if [ ! -s "$palette_cache" ]; then
    index_catalogs
  fi

  if [ -s "$palette_cache" ] && python3 "$router_tools" palette-tsv "$palette_cache"; then
    return 0
  fi

  palette_data_dynamic
}

provider_status_text() {
  local provider status found=0
  printf '# AI Router Provider Status\n\n'
  while IFS= read -r provider; do
    [ -n "$provider" ] || continue
    found=1
    if "$providers_dir/$provider.sh" --health-check >/dev/null 2>&1; then
      status="ready"
    else
      status="unavailable (CLI missing or health check failed)"
    fi
    printf -- '- %s: %s\n' "$provider" "$status"
  done < <(provider_names)

  if [ "$found" -eq 0 ]; then
    printf -- '- no executable adapters found in %s\n' "$providers_dir"
  fi
}

run_tool() {
  local name="$1"
  validate_id "$name" "tool" || return
  case "$name" in
    index)
      index_catalogs
      notify "AI Router" "Catalog index rebuilt"
      ;;
    provider-status)
      provider_status_text > "$last_output"
      /usr/bin/open "$last_output" >/dev/null 2>&1 || true
      ;;
    last-output)
      [ -f "$last_output" ] || printf '# AI Router Last Output\n\nNo output yet.\n' > "$last_output"
      /usr/bin/open "$last_output" >/dev/null 2>&1 || true
      ;;
    last-error)
      if [ -f "$last_error" ]; then
        /usr/bin/open "$last_error" >/dev/null 2>&1 || true
      else
        printf '# AI Router Last Error\n\nNo error yet.\n' > "$last_error"
        /usr/bin/open "$last_error" >/dev/null 2>&1 || true
      fi
      ;;
    config)
      /usr/bin/open "$config_dir" >/dev/null 2>&1 || true
      ;;
    prompts)
      /usr/bin/open "$prompts_dir" >/dev/null 2>&1 || true
      ;;
    snippets)
      /usr/bin/open "$snippets_dir" >/dev/null 2>&1 || true
      ;;
    logs)
      /usr/bin/open "$logs_dir" >/dev/null 2>&1 || true
      ;;
    *)
      printf 'unknown tool: %s\n' "$name" >&2
      return 64
      ;;
  esac

  record_usage "tool" "$name" "$name"
}

index_catalogs() {
  ensure_dirs
  python3 "$router_tools" index "$config_dir"
}

export_snippets() {
  local format="${1:-all}"
  ensure_dirs
  index_catalogs

  case "$format" in
    raycast)
      python3 "$router_tools" export-raycast-snippets "$config_dir" "$exports_dir/raycast-snippets.json"
      ;;
    generic)
      python3 "$router_tools" export-generic-snippets "$config_dir" "$exports_dir/ai-router-snippets.json"
      ;;
    all)
      python3 "$router_tools" export-raycast-snippets "$config_dir" "$exports_dir/raycast-snippets.json"
      python3 "$router_tools" export-generic-snippets "$config_dir" "$exports_dir/ai-router-snippets.json"
      ;;
    *)
      printf 'unknown snippet export format: %s\n' "$format" >&2
      return 64
      ;;
  esac
}

list_plain() {
  validate_id "$1" "list target" || return
  case "$1" in
    prompts) list_prompt_rows | awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' ;;
    snippets) list_snippet_rows ;;
    skills) list_skill_rows ;;
    plugins) list_plugin_rows ;;
    providers) provider_status_text ;;
    agents) agent_menu ;;
    *) usage; return 64 ;;
  esac
}

ensure_dirs

check_dependencies
rotate_logs

command="${1:-}"
shift || true

case "$command" in
  version|--version|-v)
    printf 'AI Router %s\n' "$VERSION"
    ;;
  render)
    action="${1:-}"
    [ -n "$action" ] || { usage; exit 64; }
    render_prompt "$action"
    ;;
  run)
    action="${1:-}"
    [ -n "$action" ] || { usage; exit 64; }
    run_action "$action"
    ;;
  prompt)
    action="${1:-}"
    [ -n "$action" ] || { usage; exit 64; }
    run_action "$action"
    ;;
  palette|palette-data)
    palette_data
    ;;
  agent-menu)
    agent_menu
    ;;
  agent)
    name="${1:-}"
    [ -n "$name" ] || { usage; exit 64; }
    run_agent "$name"
    ;;
  agent-run)
    name="${1:-}"
    [ -n "$name" ] || { usage; exit 64; }
    run_agent_execute "$name"
    ;;
  snippet)
    name="${1:-}"
    [ -n "$name" ] || { usage; exit 64; }
    copy_rendered_snippet "$name"
    ;;
  skill)
    name="${1:-}"
    [ -n "$name" ] || { usage; exit 64; }
    copy_skill "$name"
    ;;
  plugin)
    name="${1:-}"
    [ -n "$name" ] || { usage; exit 64; }
    copy_plugin "$name"
    ;;
  favorite)
    favorite_action "${1:-}" "${2:-}" "${3:-}" "${4:-}"
    ;;
  list)
    list_plain "${1:-}"
    ;;
  index)
    index_catalogs
    ;;
  export-snippets)
    export_snippets "${1:-all}"
    ;;
  tool)
    name="${1:-}"
    [ -n "$name" ] || { usage; exit 64; }
    run_tool "$name"
    ;;
  help|-h|--help|"")
    usage
    ;;
  *)
    usage
    exit 64
    ;;
esac
