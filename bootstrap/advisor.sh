#!/usr/bin/env bash
set -euo pipefail

# Local installation advisor. It detects facts, asks for preferences only on a
# real terminal, previews a data-only profile, and writes nothing unless
# --apply is explicit and the final confirmation succeeds.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"
# shellcheck source=catalog.sh
source "$script_dir/catalog.sh"
# shellcheck source=lib/advisor.sh
source "$script_dir/lib/advisor.sh"

advisor_usage() {
  cat <<'EOF'
Usage:
  ./bootstrap/setup.sh recommend [options]
  ./bootstrap/setup.sh tune [options]

The default is a read-only preview. On an interactive terminal, recommend asks
about common scenes and preferences; redirected/CI runs use detected defaults.

Options:
  --apply                     Apply the reviewed profile and route suggestions.
  --yes                       Skip the final confirmation (required with
                              --non-interactive --apply).
  --config-only               Write recommendation data but install no modules.
  --install                   With tune, also install any newly recommended modules.
  --no-brew                   Install/deploy modules without Homebrew commands.
  --non-interactive           Ask no questions; use flags and safe defaults.
  --scenes LIST               Comma-separated: coding,ai,web,communication,
                              writing,recording,media.
  --workspace-mode MODE       auto, focus (4), balanced (6), multitask (8),
                              or advanced (10).
  --desk MODE                 auto, flexible, or fixed display names.
  --placement POLICY          follow, prefer, or fixed for detected apps.
  --routing-pack PACK         none, suggested, creator, or author.
  --terminal APP              Terminal, Kaku, or Warp.
  --main-display NAME         Override the recommended fixed main display.
  --side-display NAME         Override the recommended fixed side display.
  --stage-display NAME        Override the recommended fixed stage display.
  --workspace-feedback VALUE  tune only: fewer, keep, or more.
  --force                     Replace a managed target after backing it up;
                              also allows replacing a symlink.
  --dry-run                   Explicit spelling of the default preview mode.
  -h, --help                  Show this help.

Test/automation inputs:
  AI_FIRST_ADVISOR_DISPLAYS_FILE      name|main(0/1)|built-in(0/1)
  AI_FIRST_ADVISOR_APPLICATIONS_FILE  known app key or bundle id, one per line
EOF
}

advisor_command="${1:-recommend}"
case "$advisor_command" in recommend|tune) ;; *) advisor_usage >&2; exit 64 ;; esac
shift || true

apply=0
assume_yes=0
non_interactive=0
config_only=0
no_brew=0
scenes=''
scenes_set=0
workspace_mode='auto'
workspace_mode_set=0
desk_mode='auto'
desk_mode_set=0
placement='prefer'
placement_set=0
routing_pack='none'
routing_pack_set=0
terminal_app='Terminal'
terminal_set=0
main_monitor=''
side_monitor=''
stage_monitor=''
workspace_feedback='keep'
workspace_feedback_set=0

[ "$advisor_command" = 'tune' ] && config_only=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --yes) assume_yes=1 ;;
    --config-only) config_only=1 ;;
    --install) config_only=0 ;;
    --no-brew) no_brew=1 ;;
    --non-interactive) non_interactive=1 ;;
    --scenes)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      scenes="$(advisor_csv_to_words "$2")"; scenes_set=1; shift
      ;;
    --workspace-mode)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      workspace_mode="$2"; workspace_mode_set=1; shift
      ;;
    --desk)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      desk_mode="$2"; desk_mode_set=1; shift
      ;;
    --placement)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      placement="$2"; placement_set=1; shift
      ;;
    --routing-pack)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      routing_pack="$2"; routing_pack_set=1; shift
      ;;
    --terminal)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      terminal_app="$2"; terminal_set=1; shift
      ;;
    --main-display)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      main_monitor="$2"; shift
      ;;
    --side-display)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      side_monitor="$2"; shift
      ;;
    --stage-display)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      stage_monitor="$2"; shift
      ;;
    --workspace-feedback)
      [ "$#" -ge 2 ] || { printf '%s needs a value.\n' "$1" >&2; exit 64; }
      workspace_feedback="$2"; workspace_feedback_set=1; shift
      ;;
    --force) DOTFILES_FORCE=1 ;;
    --dry-run) apply=0 ;;
    -h|--help) advisor_usage; exit 0 ;;
    *) printf 'Unknown advisor option: %s\n\n' "$1" >&2; advisor_usage >&2; exit 64 ;;
  esac
  shift
done

case "$workspace_mode" in auto|focus|balanced|multitask|advanced) ;; *) printf 'Invalid workspace mode: %s\n' "$workspace_mode" >&2; exit 64 ;; esac
case "$desk_mode" in auto|flexible|fixed) ;; *) printf 'Invalid desk mode: %s\n' "$desk_mode" >&2; exit 64 ;; esac
case "$placement" in follow|prefer|fixed) ;; *) printf 'Invalid placement policy: %s\n' "$placement" >&2; exit 64 ;; esac
case "$routing_pack" in none|suggested|creator|author) ;; *) printf 'Invalid routing pack: %s\n' "$routing_pack" >&2; exit 64 ;; esac
case "$terminal_app" in Terminal|Kaku|Warp) ;; *) printf 'Terminal must be Terminal, Kaku, or Warp.\n' >&2; exit 64 ;; esac
case "$workspace_feedback" in fewer|keep|more) ;; *) printf 'Workspace feedback must be fewer, keep, or more.\n' >&2; exit 64 ;; esac

interactive=0
if [ "$non_interactive" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then
  interactive=1
fi
if [ "$apply" -eq 1 ] && [ "$interactive" -eq 0 ] && [ "$assume_yes" -ne 1 ]; then
  printf 'Non-interactive --apply requires --yes. Previewing remains the default.\n' >&2
  exit 64
fi

advisor_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ai-first-advisor.XXXXXX")"
trap 'rm -rf "$advisor_tmp"' EXIT
displays_file="$advisor_tmp/displays"
apps_file="$advisor_tmp/apps"
profile_candidate="$advisor_tmp/profile.conf"
routes_candidate="$advisor_tmp/advisor-routes.conf"

advisor_detect_displays "$displays_file"
advisor_detect_apps "$apps_file"
display_count="$(advisor_display_count "$displays_file")"
[ "$display_count" -gt 0 ] || display_count=1

advisor_prompt() {
  local prompt="$1" default_value="$2" answer=''
  printf '%s [%s]: ' "$prompt" "$default_value" >&2
  IFS= read -r answer || answer=''
  printf '%s\n' "${answer:-$default_value}"
}

advisor_print_detected() {
  local name main builtin key bundle display scene role layout
  printf 'Detected locally (nothing has been changed)\n\n'
  printf 'Displays: %s (%s)\n' "$display_count" "$ADVISOR_DISPLAY_SOURCE"
  while IFS='|' read -r name main builtin _rest; do
    printf '  - %s' "$name"
    [ "$main" = '1' ] && printf ' [suggested main]'
    [ "$builtin" = '1' ] && printf ' [built-in]'
    printf '\n'
  done <"$displays_file"
  case "$ADVISOR_DISPLAY_SOURCE" in
    'CoreGraphics count only')
      printf '  Names were unavailable; flexible layout can still use this count.\n'
      ;;
    fallback)
      printf '  Display detection was unavailable; using a conservative one-screen preview.\n'
      ;;
  esac
  printf 'Installed applications recognized by the advisor:\n'
  if [ -s "$apps_file" ]; then
    while IFS='|' read -r key bundle display scene role layout _rest; do
      printf '  - %-22s %s\n' "$display" "$scene"
    done <"$apps_file"
  else
    printf '  - none of the optional known applications; system defaults remain usable\n'
  fi
  printf '\nDetection is local and is not stored or sent anywhere.\n\n'
}

advisor_parse_scene_answer() {
  local answer="$(printf '%s' "$1" | tr ',' ' ')" result='' token
  for token in $answer; do
    case "$token" in
      1|coding) token='coding' ;;
      2|ai) token='ai' ;;
      3|web) token='web' ;;
      4|communication) token='communication' ;;
      5|writing) token='writing' ;;
      6|recording) token='recording' ;;
      7|media) token='media' ;;
      *) printf 'Unknown scene selection: %s\n' "$token" >&2; return 1 ;;
    esac
    result="$(advisor_append_word_once "$result" "$token")"
  done
  [ -n "$result" ] || return 1
  printf '%s\n' "$result"
}

advisor_choose_display() {
  local role="$1" default_name="$2" answer='' chosen
  printf '%s display number [%s]: ' "$role" "$default_name" >&2
  IFS= read -r answer || answer=''
  if [ -z "$answer" ]; then
    printf '%s\n' "$default_name"
    return 0
  fi
  case "$answer" in *[!0-9]*|'') printf 'Enter a display number from the detected list.\n' >&2; return 1 ;; esac
  chosen="$(advisor_display_name_at "$displays_file" "$answer")"
  [ -n "$chosen" ] || { printf 'No display number %s.\n' "$answer" >&2; return 1; }
  printf '%s\n' "$chosen"
}

profile_path="${AI_FIRST_PROFILE_PATH:-$HOME/.config/ai-first/profile.conf}"

if [ "$advisor_command" = 'tune' ]; then
  if [ ! -r "$profile_path" ]; then
    printf 'No current advisor profile at %s. Run setup.sh recommend first.\n' "$profile_path" >&2
    exit 66
  fi
  current_preset="$(advisor_profile_get "$profile_path" AI_FIRST_PRESET 2>/dev/null || true)"
  if [ "$current_preset" != 'advisor' ]; then
    printf 'The active profile is %s, not an advisor-generated profile.\n' "${current_preset:-unknown}" >&2
    printf 'Run setup.sh recommend to preview a migration without changing it.\n' >&2
    exit 65
  fi
  [ "$scenes_set" -eq 1 ] || scenes="$(advisor_profile_get "$profile_path" AI_FIRST_ADVISOR_SCENES 2>/dev/null || printf 'coding web')"
  [ "$workspace_mode_set" -eq 1 ] || workspace_mode="$(advisor_profile_get "$profile_path" AI_FIRST_ADVISOR_WORKSPACE_MODE 2>/dev/null || printf 'balanced')"
  [ "$desk_mode_set" -eq 1 ] || desk_mode="$(advisor_profile_get "$profile_path" AI_FIRST_ADVISOR_DESK_MODE 2>/dev/null || printf 'flexible')"
  [ "$placement_set" -eq 1 ] || placement="$(advisor_profile_get "$profile_path" AI_FIRST_ADVISOR_PLACEMENT 2>/dev/null || printf 'prefer')"
  [ "$routing_pack_set" -eq 1 ] || routing_pack="$(advisor_profile_get "$profile_path" AI_FIRST_ROUTING_PACK 2>/dev/null || printf 'none')"
  [ "$terminal_set" -eq 1 ] || terminal_app="$(advisor_profile_get "$profile_path" AI_FIRST_TERMINAL_APP 2>/dev/null || printf 'Terminal')"
  if [ "$desk_mode" = 'fixed' ]; then
    [ -n "$main_monitor" ] || main_monitor="$(advisor_profile_get "$profile_path" AEROSPACE_MAIN_MONITOR_NAME 2>/dev/null || true)"
    [ -n "$side_monitor" ] || side_monitor="$(advisor_profile_get "$profile_path" AEROSPACE_SIDE_MONITOR_NAME 2>/dev/null || true)"
    [ -n "$stage_monitor" ] || stage_monitor="$(advisor_profile_get "$profile_path" AEROSPACE_STAGE_MONITOR_NAME 2>/dev/null || true)"
  fi
fi

advisor_print_detected

if [ -z "$scenes" ]; then
  scenes="$(advisor_detected_scenes "$apps_file")"
fi
advisor_validate_scenes "$scenes" || exit 64

if [ "$interactive" -eq 1 ] && [ "$advisor_command" = 'recommend' ] && [ "$scenes_set" -eq 0 ]; then
  printf 'Common scenes (choose several):\n'
  printf '  1 coding   2 AI   3 web/research   4 communication\n'
  printf '  5 writing  6 recording   7 media\n'
  scene_answer="$(advisor_prompt 'Scene numbers, comma-separated' "$(printf '%s' "$scenes" | tr ' ' ',')")"
  scenes="$(advisor_parse_scene_answer "$scene_answer")" || exit 64
fi

if [ "$interactive" -eq 1 ] && [ "$terminal_set" -eq 0 ]; then
  terminal_choices='Terminal'
  /usr/bin/grep -Eq '^kaku\|' "$apps_file" && terminal_choices="$terminal_choices Kaku"
  /usr/bin/grep -Eq '^warp\|' "$apps_file" && terminal_choices="$terminal_choices Warp"
  if [ "$terminal_choices" != 'Terminal' ]; then
    printf 'Detected terminal choices: %s\n' "$terminal_choices"
    terminal_app="$(advisor_prompt 'Terminal used by AI/app openers' "$terminal_app")"
    case " $terminal_choices " in
      *" $terminal_app "*) ;;
      *) printf '%s was not one of the detected terminal choices.\n' "$terminal_app" >&2; exit 64 ;;
    esac
  fi
fi

if [ "$workspace_mode" = 'auto' ]; then
  workspace_mode="$(advisor_recommend_workspace_mode "$scenes" "$display_count")"
fi
# The author pack retains two explicit compatibility targets (4 and 5). A
# four-workspace profile cannot resolve target 5, so an explicit author choice
# gets the smallest valid advisor layout rather than a silently ignored rule.
if [ "$routing_pack" = 'author' ] && [ "$workspace_mode" = 'focus' ]; then
  workspace_mode='balanced'
fi

if [ "$advisor_command" = 'tune' ]; then
  if [ "$interactive" -eq 1 ] && [ "$workspace_feedback_set" -eq 0 ]; then
    workspace_feedback="$(advisor_prompt 'Workspace count feels fewer, keep, or more?' keep)"
  fi
  case "$workspace_feedback" in fewer|keep|more) ;; *) printf 'Feedback must be fewer, keep, or more.\n' >&2; exit 64 ;; esac
  workspace_mode="$(advisor_workspace_mode_step "$workspace_mode" "$workspace_feedback")"
fi
if [ "$routing_pack" = 'author' ] && [ "$workspace_mode" = 'focus' ]; then
  workspace_mode='balanced'
fi

if [ "$desk_mode" = 'auto' ]; then
  desk_mode='flexible'
fi
if [ "$interactive" -eq 1 ] && [ "$display_count" -gt 1 ] && [ "$desk_mode_set" -eq 0 ]; then
  desk_mode="$(advisor_prompt 'Display behavior: flexible or fixed?' "$desk_mode")"
fi
case "$desk_mode" in flexible|fixed) ;; *) printf 'Desk mode must be flexible or fixed.\n' >&2; exit 64 ;; esac

if [ "$interactive" -eq 1 ] && [ "$placement_set" -eq 0 ]; then
  placement="$(advisor_prompt 'Detected apps: follow, prefer, or fixed?' "$placement")"
fi
case "$placement" in follow|prefer|fixed) ;; *) printf 'Placement must be follow, prefer, or fixed.\n' >&2; exit 64 ;; esac

default_main="$(advisor_default_main_display "$displays_file")"
default_stage=''
default_side=''
if [ "$display_count" -ge 3 ]; then
  default_stage="$(advisor_default_stage_display "$displays_file")"
fi
if [ "$display_count" -ge 2 ]; then
  default_side="$(advisor_default_side_display "$displays_file" "$default_main" "$default_stage")"
fi

if [ "$desk_mode" = 'fixed' ]; then
  if [ "${ADVISOR_DISPLAY_NAMES_RELIABLE:-0}" -ne 1 ] && \
     { [ "$advisor_command" != 'tune' ] || [ -z "$main_monitor" ]; }; then
    printf 'The display count is usable, but macOS did not expose stable display names.\n' >&2
    printf 'Use flexible mode now, then re-run tune --desk fixed after AeroSpace or Hammerspoon is running.\n' >&2
    exit 69
  fi
  [ -n "$main_monitor" ] || main_monitor="$default_main"
  [ -n "$side_monitor" ] || side_monitor="$default_side"
  [ -n "$stage_monitor" ] || stage_monitor="$default_stage"
  if [ "$interactive" -eq 1 ] && [ "$advisor_command" = 'recommend' ]; then
    printf '\nDetected display numbers:\n'
    /usr/bin/awk -F '|' '{ printf "  %s  %s\n", NR, $1 }' "$displays_file"
    main_monitor="$(advisor_choose_display main "$main_monitor")" || exit 64
    if [ "$display_count" -ge 2 ]; then
      side_monitor="$(advisor_choose_display side "$side_monitor")" || exit 64
    fi
    if [ "$display_count" -ge 3 ]; then
      stage_monitor="$(advisor_choose_display stage "$stage_monitor")" || exit 64
    fi
  fi
  if [ -n "$side_monitor" ] && [ "$side_monitor" = "$main_monitor" ]; then
    printf 'Fixed main and side displays must be different. Use flexible mode to allow collapse.\n' >&2
    exit 64
  fi
  if [ -n "$stage_monitor" ] && { [ "$stage_monitor" = "$main_monitor" ] || [ "$stage_monitor" = "$side_monitor" ]; }; then
    printf 'Fixed stage display must be distinct. Use flexible mode to allow collapse.\n' >&2
    exit 64
  fi
else
  main_monitor=''
  side_monitor=''
  stage_monitor=''
fi

plan_display_count="$display_count"
if [ "$advisor_command" = 'tune' ] && [ "$desk_mode" = 'fixed' ]; then
  # A temporarily unplugged fixed display must not collapse the saved desk just
  # because feedback was given from a laptop-only session.
  [ -z "$side_monitor" ] || plan_display_count=2
  [ -z "$stage_monitor" ] || plan_display_count=3
fi
advisor_build_workspace_plan "$workspace_mode" "$plan_display_count"
modules="$(advisor_recommended_modules "$scenes")"
advisor_generate_profile "$profile_candidate" "$scenes" "$workspace_mode" "$desk_mode" \
  "$placement" "$routing_pack" "$terminal_app" "$main_monitor" "$side_monitor" "$stage_monitor"
advisor_generate_routes "$routes_candidate" "$apps_file" "$scenes" "$placement"

printf 'Recommended plan\n\n'
printf '  Scenes:             %s\n' "$scenes"
printf '  Workspace mode:     %s (%s workspaces)\n' "$workspace_mode" "$(printf '%s\n' "$ADVISOR_WORKSPACES" | wc -w | tr -d ' ')"
printf '  Display behavior:   %s\n' "$desk_mode"
printf '  Main workspaces:    %s%s\n' "$ADVISOR_MAIN_WORKSPACES" "${main_monitor:+ on $main_monitor}"
printf '  Side workspaces:    %s%s\n' "${ADVISOR_SIDE_WORKSPACES:--}" "${side_monitor:+ on $side_monitor}"
printf '  Stage workspaces:   %s%s\n' "${ADVISOR_STAGE_WORKSPACES:--}" "${stage_monitor:+ on $stage_monitor}"
printf '  App placement:      %s\n' "$placement"
printf '  Shipped route pack: %s\n' "$routing_pack"
printf '  Terminal target:    %s\n' "$terminal_app"
printf '  Modules:            %s\n' "$modules"
printf '  Notifications:      off (Full Disk Access is never inferred)\n'
printf '  Paid/closed apps:   never installed by this recommendation\n'
printf '\nRecommended module details:\n'
for module in $modules; do
  printf '  - %-12s %s\n' "$module" "$(catalog_module_description "$module")"
  printf '    cost: %s; permissions: %s\n' \
    "$(catalog_module_cost "$module")" "$(catalog_module_permissions "$module")"
done

route_count="$(/usr/bin/awk -F '|' '$1 == "id" { count++ } END { print count + 0 }' "$routes_candidate")"
printf '\nDetected-app route suggestions: %s\n' "$route_count"
if [ "$route_count" -gt 0 ]; then
  /usr/bin/awk -F '|' 'NR==FNR { if ($1 == "id") route[$2]=$3 " / " $4 " / " $5; next }
    route[$2] != "" { printf "  - %-22s %s\n", $3, route[$2] }' "$routes_candidate" "$apps_file"
else
  printf '  - none; applications stay where opened\n'
fi

profile_target="$profile_path"
routes_target="${AI_FIRST_ADVISOR_ROUTES_FILE:-$HOME/.config/ai-first/advisor-routes.conf}"
printf '\nFiles that would be generated:\n'
printf '  %s\n' "$profile_target"
printf '  %s\n' "$routes_target"
printf '\nThe handwritten app-routes.conf is not replaced. It remains the highest-priority layer.\n'

if [ "$apply" -ne 1 ]; then
  printf '\nPreview only: nothing was written or installed.\n'
  printf 'Review the plan, then re-run with --apply.\n'
  printf 'For exact package commands and deploy paths, preview the recommended modules:\n  ./bootstrap/setup.sh'
  for module in $modules; do printf ' %s' "$module"; done
  printf ' --dry-run\n'
  exit 0
fi

if [ "$interactive" -eq 1 ] && [ "$assume_yes" -ne 1 ]; then
  answer="$(advisor_prompt 'Apply this plan now? yes or no' no)"
  case "$answer" in yes|y|Y) ;; *) printf 'Cancelled; nothing was changed.\n'; exit 0 ;; esac
fi

advisor_target_writable() {
  local target="$1"
  if [ -L "$target" ] && ! deploy_force_enabled; then
    printf 'Refusing to replace symlink: %s\n' "$target" >&2
    printf 'Move it aside or re-run with --force; nothing has been written.\n' >&2
    return 1
  fi
  return 0
}

advisor_apply_generated_file() {
  local source_file="$1" target="$2" source_label="$3" stamp backup_path
  if cmp -s "$source_file" "$target" 2>/dev/null; then
    printf 'Unchanged: %s\n' "$target"
    return 0
  fi
  ensure_deploy_dir "$(dirname "$target")" "$source_label" || return 1
  stamp="$(date +%Y%m%d_%H%M%S)"
  backup_target "$target" "$stamp"
  backup_path="$DOTFILES_BACKUP_PATH"
  cp "$source_file" "$target"
  chmod 0644 "$target" 2>/dev/null || true
  ledger_record "$source_label" "$target" "$backup_path"
  printf 'Applied: %s\n' "$target"
}

# Refuse every problematic target before changing either one.
advisor_target_writable "$profile_target"
advisor_target_writable "$routes_target"

if [ "$config_only" -eq 0 ]; then
  require_prerequisites
fi

advisor_apply_generated_file "$profile_candidate" "$profile_target" 'generated/advisor/profile.conf'
advisor_apply_generated_file "$routes_candidate" "$routes_target" 'generated/advisor/advisor-routes.conf'

install_status=0
if [ "$config_only" -eq 0 ]; then
  setup_args=()
  for module in $modules; do setup_args+=("$module"); done
  [ "$no_brew" -eq 0 ] || setup_args+=(--no-brew)
  "$script_dir/setup.sh" "${setup_args[@]}" || install_status=$?
else
  printf 'Configuration only: no package or module installation was run.\n'
fi

if [ -x "$HOME/.config/aerospace/render-layout.sh" ] && [ -f "$HOME/.aerospace.toml" ]; then
  "$HOME/.config/aerospace/render-layout.sh" "$HOME/.aerospace.toml" || true
  if command -v aerospace >/dev/null 2>&1 && \
     aerospace reload-config --dry-run --no-gui >/dev/null 2>&1; then
    aerospace reload-config >/dev/null 2>&1 || true
  fi
fi
if [ -f "$HOME/.hammerspoon/init.lua" ] && command -v hs >/dev/null 2>&1; then
  hs -c 'hs.reload()' >/dev/null 2>&1 || true
fi
if [ -f "$HOME/.config/sketchybar/sketchybarrc" ] && command -v sketchybar >/dev/null 2>&1; then
  sketchybar --reload >/dev/null 2>&1 || true
fi

printf '\nApplied recommendation. Inspect the resolved result with:\n'
printf '  ~/.config/aerospace/plan.sh --check\n'
printf 'After arranging windows naturally, capture a local follow/prefer proposal with:\n'
printf '  ~/.config/aerospace/app-route.sh capture-current\n'

exit "$install_status"
