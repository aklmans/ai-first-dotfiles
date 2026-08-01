#!/usr/bin/env bash

# App placement and floating rules, in one place, in two forms: shell functions
# for the scripts that sort existing windows, and TOML for AeroSpace's own
# on-window-detected rules. render-app-rules.sh renders the second from the
# first so the two cannot drift.
#
# Placement is selected from a routing pack and resolves semantic targets such
# as `stage` or `communication` through lib/layout.sh. A route whose target is
# absent is ignored and reported by plan.sh instead of being silently crowded
# onto the user's last workspace. Generic floating/tiling behavior stays here
# because window shape and workspace ownership are independent choices.

_app_defaults_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
if [ -r "$_app_defaults_dir/lib/layout.sh" ]; then
    # shellcheck source=lib/layout.sh
    . "$_app_defaults_dir/lib/layout.sh"
    # Load the workspace profile before the general profile reader below. This
    # preserves explicit empty side/stage lists instead of restoring the
    # thirteen-workspace shipped defaults while app rules are rendered.
    aerospace_layout_load_config
fi

_ai_first_profile_lib="${AI_FIRST_PROFILE_LIB:-$HOME/.config/ai-first/lib/profile.sh}"
if [ -r "$_ai_first_profile_lib" ]; then
    # shellcheck source=/dev/null
    . "$_ai_first_profile_lib"
fi

aerospace_app_routing_enabled() {
    case "${AI_FIRST_APP_ROUTING:-1}" in
        1|true|TRUE|yes|YES|on|ON|enabled|ENABLED) return 0 ;;
        *) return 1 ;;
    esac
}

aerospace_app_routes_file() {
    printf '%s\n' "${AI_FIRST_APP_ROUTES_FILE:-$HOME/.config/aerospace/app-routes.conf}"
}

aerospace_advisor_routes_file() {
    printf '%s\n' "${AI_FIRST_ADVISOR_ROUTES_FILE:-$HOME/.config/ai-first/advisor-routes.conf}"
}

aerospace_captured_routes_file() {
    printf '%s\n' "${AI_FIRST_CAPTURED_ROUTES_FILE:-$HOME/.config/ai-first/captured-routes.conf}"
}

aerospace_routing_pack() {
    local pack="${AI_FIRST_ROUTING_PACK:-author}"
    case "$pack" in ''|*[!a-z0-9_-]*) pack='none' ;; esac
    [ -r "$_app_defaults_dir/routing-packs/$pack.conf" ] || pack='none'
    printf '%s\n' "$pack"
}

aerospace_routing_pack_file() {
    printf '%s/routing-packs/%s.conf\n' "$_app_defaults_dir" "$(aerospace_routing_pack)"
}

# Normalized route fields are returned through globals so the same parser can
# serve runtime placement, TOML rendering, doctor and the focus-first editor.
# Four-column records remain compatible:
#   target=current -> follow, target=- -> layout-only, otherwise fixed.
AEROSPACE_ROUTE_TARGET=''
AEROSPACE_ROUTE_POLICY=''
AEROSPACE_ROUTE_LAYOUT=''
AEROSPACE_ROUTE_WORKSPACE=''
aerospace_normalize_route_fields() {
    local target="${1:-}" field4="${2:-}" field5="${3:-}"
    local policy layout workspace

    if [ -n "$field5" ]; then
        policy="$field4"
        layout="$field5"
    else
        layout="$field4"
        case "$target" in
            current) policy='follow' ;;
            -|'') policy='inherit' ;;
            *) policy='fixed' ;;
        esac
    fi

    case "$layout" in tiling|floating) ;; -|'') layout='' ;; *) return 1 ;; esac
    workspace=''
    case "$policy" in
        follow)
            target='current'
            ;;
        prefer|fixed)
            case "$target" in current|-|'') return 1 ;; esac
            workspace="$(aerospace_layout_resolve_route_target "$target" 2>/dev/null)" || return 1
            case "$workspace" in ''|*[!A-Za-z0-9_-]*) return 1 ;; esac
            ;;
        inherit)
            case "$target" in -|'') ;; *) return 1 ;; esac
            [ -n "$layout" ] || return 1
            target=''
            ;;
        *)
            return 1
            ;;
    esac

    AEROSPACE_ROUTE_TARGET="$target"
    AEROSPACE_ROUTE_POLICY="$policy"
    AEROSPACE_ROUTE_LAYOUT="$layout"
    AEROSPACE_ROUTE_WORKSPACE="$workspace"
}

aerospace_route_from_file() {
    local routes_file="$1" app_id="${2:-}" app_name="${3:-}"
    local kind value target field4 field5 rest

    [ -r "$routes_file" ] || return 1
    while IFS='|' read -r kind value target field4 field5 rest; do
        case "$kind" in ''|'#'*) continue ;; esac
        [ -z "${rest:-}" ] || continue
        case "$kind" in
            id) [ "$value" = "$app_id" ] || continue ;;
            name) [ "$value" = "$app_name" ] || continue ;;
            *) continue ;;
        esac
        case "$value" in ''|*"'"*) continue ;; esac
        aerospace_normalize_route_fields "$target" "$field4" "$field5" || continue
        printf '%s|%s|%s|%s\n' \
            "$AEROSPACE_ROUTE_TARGET" "$AEROSPACE_ROUTE_POLICY" \
            "$AEROSPACE_ROUTE_LAYOUT" "$AEROSPACE_ROUTE_WORKSPACE"
        return 0
    done < "$routes_file"
    return 1
}

aerospace_user_route() {
    aerospace_route_from_file "$(aerospace_app_routes_file)" "${1:-}" "${2:-}"
}

aerospace_captured_route() {
    aerospace_route_from_file "$(aerospace_captured_routes_file)" "${1:-}" "${2:-}"
}

aerospace_advisor_route() {
    aerospace_route_from_file "$(aerospace_advisor_routes_file)" "${1:-}" "${2:-}"
}

aerospace_pack_route() {
    [ "$(aerospace_routing_pack)" != 'none' ] || return 1
    aerospace_route_from_file "$(aerospace_routing_pack_file)" "${1:-}" "${2:-}"
}

# Lowest user-specific route after handwritten data: a captured desktop wins
# over install-time advice, and either wins over an optional shipped pack.
aerospace_recommended_route() {
    local app_id="${1:-}" app_name="${2:-}" route

    if route="$(aerospace_captured_route "$app_id" "$app_name" 2>/dev/null)"; then
        printf '%s\n' "$route"
        return 0
    fi
    if route="$(aerospace_advisor_route "$app_id" "$app_name" 2>/dev/null)"; then
        printf '%s\n' "$route"
        return 0
    fi
    aerospace_pack_route "$app_id" "$app_name"
}

# Handwritten user data has priority. A legacy layout-only record merges with
# captured/advisor/pack placement; without any lower route it becomes a
# follow-current layout choice.
aerospace_route_for_window() {
    local app_id="${1:-}" app_name="${2:-}"
    local user_route recommended_route user_policy user_layout

    if user_route="$(aerospace_user_route "$app_id" "$app_name" 2>/dev/null)"; then
        user_policy="$(printf '%s' "$user_route" | /usr/bin/awk -F '|' '{ print $2 }')"
        if [ "$user_policy" != 'inherit' ]; then
            printf '%s\n' "$user_route"
            return 0
        fi
        user_layout="$(printf '%s' "$user_route" | /usr/bin/awk -F '|' '{ print $3 }')"
        if recommended_route="$(aerospace_recommended_route "$app_id" "$app_name" 2>/dev/null)"; then
            # "\\n" in an awk format string is a literal backslash followed by n,
            # not a newline. It used to append those two characters to the
            # workspace field, which then failed every comparison downstream and
            # silently clamped the app onto the last workspace.
            printf '%s' "$recommended_route" | /usr/bin/awk -F '|' -v layout="$user_layout" \
                '{ printf "%s|%s|%s|%s\n", $1, $2, layout, $4 }'
        else
            printf 'current|follow|%s|\n' "$user_layout"
        fi
        return 0
    fi

    aerospace_recommended_route "$app_id" "$app_name"
}

aerospace_route_field() {
    local route
    route="$(aerospace_route_for_window "$1" "$2")" || return 1
    case "$3" in
        target) printf '%s\n' "$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $1 }')" ;;
        policy) printf '%s\n' "$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $2 }')" ;;
        layout) printf '%s\n' "$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $3 }')" ;;
        workspace) printf '%s\n' "$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $4 }')" ;;
        *) return 1 ;;
    esac
}

# Kept for scripts written against the four-column route API.
aerospace_user_route_field() {
    local route
    route="$(aerospace_user_route "$1" "$2")" || return 1
    case "$3" in
        workspace) printf '%s\n' "$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $4 }')" ;;
        layout) printf '%s\n' "$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $3 }')" ;;
        *) return 1 ;;
    esac
}

aerospace_regex_escape() {
    printf '%s' "${1:-}" | /usr/bin/sed 's/[][\\.^$*+?(){}|]/\\&/g'
}

# Copied out of a deployment without its library, this file still has to be a
# usable set of rules rather than a syntax error waiting to happen.
if ! type aerospace_layout_clamp_workspace >/dev/null 2>&1; then
    aerospace_layout_clamp_workspace() {
        case "${1:-}" in
            ''|*[!A-Za-z0-9_-]*) return 1 ;;
        esac
        printf '%s\n' "$1"
    }
    aerospace_layout_clamp_workspace_stream() {
        cat
    }
fi

is_jetbrains_app() {
    local app_id="${1:-}"
    local app_name="${2:-}"

    case "$app_id" in
        com.jetbrains.*|com.google.android.studio)
            return 0
            ;;
    esac

    case "$app_name" in
        "GoLand"|"IntelliJ IDEA"|"IntelliJ IDEA-EAP"|"WebStorm"|"PhpStorm"|"RustRover"|"PyCharm"|"CLion"|"DataGrip"|"Rider"|"Android Studio")
            return 0
            ;;
    esac

    return 1
}

is_jetbrains_dialog_title() {
    local title="${1:-}"

    case "$title" in
        "Welcome to"*|"Settings"|"Preferences"|"Project Structure"*|"Run/Debug Configurations"*|"Edit Configuration"*|"Plugins"|"Tip of the Day"*|"New Project"*|"Open File or Project"*|"Attach Directory"*|"About"*|"Licenses"*|"Choose"*|"Select"*|"Import"*|"Export"*|"Find"*|"Replace"*|"Search Everywhere"*|"Local History"*|"Commit"*|"Push"*|"Pull"*|"Merge"*|"Rebase"*|"Checkout"*|"Branch"*|"Clone Repository"*|"Refactor"*|"Extract"*|"Inline"*|"Change Signature"*|"Delete"*|"Rename"*|"Remove"*|"Move"*|"Copy"*|"Add File to Git"*|"Edit Commit Message"*|"Confirm"*|"Discard"*|"Overwrite"*|"File Already Exists"*|"Resolve Conflicts"*)
            return 0
            ;;
    esac

    return 1
}

is_context_dialog_title() {
    local title="${1:-}"

    case "$title" in
        "Settings"*|\
        "Preferences"*|\
        "Options"*|\
        "Licenses"*|\
        "Choose"*|\
        "Select"*|\
        "Open"*|\
        "Save"*|\
        "Save As"*|\
        "Export"*|\
        "Import"*|\
        "Find"*|\
        "Replace"*|\
        "Print"*|\
        "Search"*|\
        "Keyboard Shortcuts"*|\
        "Extensions"*|\
        "Plugins"*|\
        "Account"*|\
        "Profile"*|\
        "Sign in"*|\
        "Login"*|\
        "设置"*|\
        "偏好设置"*|\
        "选项"*|\
        "关于"*|\
        "打开"*|\
        "保存"*|\
        "导出"*|\
        "导入"*|\
        "查找"*|\
        "替换"*|\
        "打印"*|\
        "账户"*|\
        "登录"*)
            return 0
            ;;
    esac

    return 1
}

should_float_window() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local title="${3:-}"

    aerospace_app_routing_enabled || return 1

    if is_context_dialog_title "$title"; then
        return 0
    fi

    if is_jetbrains_app "$app_id" "$app_name" && is_jetbrains_dialog_title "$title"; then
        return 0
    fi

    local route_layout
    route_layout="$(aerospace_route_field "$app_id" "$app_name" layout 2>/dev/null || true)"
    case "$route_layout" in
        floating) return 0 ;;
        tiling) return 1 ;;
    esac

    # What is left here is the macOS surface itself: the apps every Mac has,
    # whose windows are utility surfaces rather than work surfaces. Deciding
    # that Finder floats is a statement about macOS.
    #
    # Deciding that Clash for Windows, Bilibili, WeChat or Typeless float is a
    # statement about one person's software, and those lists moved into
    # routing-packs/ - author.conf for the author's own inventory, suggested.conf
    # for the widely used ones. They used to sit right here, which meant a
    # profile that selected the `none` pack, documented as shipping no app
    # placement, still got eighty lines of somebody else's app list.
    case "$app_id" in
        com.apple.finder|com.apple.systempreferences|com.apple.ActivityMonitor|com.apple.mail|com.apple.Photos|com.apple.Preview|com.apple.archiveutility|com.apple.AppStore)
            return 0
            ;;
        com.microsoft.Powerpoint|com.apple.iWork.Keynote)
            return 0
            ;;
    esac

    case "$app_name" in
        "Finder"|"访达"|"System Settings"|"System Preferences"|"系统设置"|"Activity Monitor"|"监视器"|"Stats"|"Mail"|"邮件"|"Photos"|"照片"|"Preview"|"预览"|"Microsoft PowerPoint"|"Keynote"*)
            return 0
            ;;
    esac

    return 1
}

should_tile_window() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local title="${3:-}"

    aerospace_app_routing_enabled || return 1

    if should_float_window "$app_id" "$app_name" "$title"; then
        return 1
    fi

    local route_layout
    route_layout="$(aerospace_route_field "$app_id" "$app_name" layout 2>/dev/null || true)"
    case "$route_layout" in
        tiling) return 0 ;;
        floating) return 1 ;;
    esac

    if is_jetbrains_app "$app_id" "$app_name"; then
        return 0
    fi

    case "$app_id" in
        dev.warp.Warp-Stable|fun.tw93.kaku|com.microsoft.VSCode|com.microsoft.VSCodeInsiders|com.sublimetext.4|com.todesktop.230313mzl4w4u92)
            return 0
            ;;
        company.thebrowser.Browser|company.thebrowser.dia|com.apple.Safari|com.microsoft.edgemac|com.google.Chrome|org.mozilla.firefox|app.zen-browser.zen)
            return 0
            ;;
        md.obsidian|com.tw93.miaoyan|com.openai.chat|com.openai.atlas|ai.marswave.cola|com.google.GeminiMacOS)
            return 0
            ;;
        com.blade.shadow-macos)
            return 0
            ;;
    esac

    case "$app_name" in
        "Warp"|"Kaku"|"Cursor"|"Visual Studio Code"|"Code"|"Code - Insiders"|"Sublime Text"|"GoLand"|"IntelliJ IDEA"|"IntelliJ IDEA-EAP"|"WebStorm"|"PhpStorm"|"RustRover"|"PyCharm"|"CLion"|"DataGrip"|"Rider"|"Android Studio")
            return 0
            ;;
        "Arc"|"Dia"|"Safari"|"Microsoft Edge"|"Google Chrome"|"Firefox"|"Zen")
            return 0
            ;;
        "Obsidian"|"MiaoYan"|"Cola"|"ChatGPT"|"ChatGPT Atlas"|"Gemini"|"Shadow"|"Shadow PC"|"ShadowPCDisplay")
            return 0
            ;;
    esac

    return 1
}

default_workspace_for_window() {
    local raw

    raw="$(default_workspace_rule_for_window "$@")" || return 1
    [ -n "$raw" ] || return 1

    aerospace_layout_clamp_workspace "$raw"
}

default_workspace_rule_for_window() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local title="${3:-}"
    local route policy workspace

    aerospace_app_routing_enabled || return 1

    if is_context_dialog_title "$title"; then
        return 1
    fi

    if is_jetbrains_app "$app_id" "$app_name" && is_jetbrains_dialog_title "$title"; then
        return 1
    fi

    route="$(aerospace_route_for_window "$app_id" "$app_name" 2>/dev/null)" || return 1
    policy="$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $2 }')"
    workspace="$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $4 }')"
    case "$policy" in
        fixed|prefer) [ -n "$workspace" ] || return 1 ;;
        *) return 1 ;;
    esac
    printf '%s' "$workspace"
}

emit_on_window_detected_rules() {
    if ! aerospace_app_routing_enabled; then
        printf '%s\n' '# Application placement and floating rules.'
        printf '%s\n' '# Disabled by ~/.config/ai-first/profile.conf (AI_FIRST_APP_ROUTING="0").'
        return 0
    fi
    {
        printf '%s\n' '# Application placement and floating rules.'
        printf '%s\n' '# Keep this block aligned with ~/.config/aerospace/app-defaults.sh.'
        emit_on_window_detected_rules_raw
        emit_user_on_window_detected_rules
        emit_captured_on_window_detected_rules
        emit_advisor_on_window_detected_rules
        emit_pack_on_window_detected_rules
    } | aerospace_layout_clamp_workspace_stream
}

emit_routes_file_as_toml() {
    local routes_file="$1" source="${2:-pack}"
    local kind value target field4 field5 rest route
    local policy layout workspace run_layout run_workspace

    [ -r "$routes_file" ] || return 0
    while IFS='|' read -r kind value target field4 field5 rest; do
        case "$kind" in ''|'#'*) continue ;; esac
        [ -z "${rest:-}" ] || continue
        case "$kind" in id|name) ;; *) continue ;; esac
        case "$value" in ''|*"'"*) continue ;; esac
        aerospace_normalize_route_fields "$target" "$field4" "$field5" || continue

        route="$AEROSPACE_ROUTE_TARGET|$AEROSPACE_ROUTE_POLICY|$AEROSPACE_ROUTE_LAYOUT|$AEROSPACE_ROUTE_WORKSPACE"
        if [ "$source" = 'user' ] && [ "$AEROSPACE_ROUTE_POLICY" = 'inherit' ]; then
            if [ "$kind" = id ]; then
                route="$(aerospace_route_for_window "$value" '' 2>/dev/null)" || continue
            else
                route="$(aerospace_route_for_window '' "$value" 2>/dev/null)" || continue
            fi
        fi
        policy="$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $2 }')"
        layout="$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $3 }')"
        workspace="$(printf '%s' "$route" | /usr/bin/awk -F '|' '{ print $4 }')"

        printf '%s\n' '[[on-window-detected]]'
        if [ "$kind" = id ]; then
            printf "    if.app-id = '%s'\n" "$value"
        else
            printf "    if.app-name-regex-substring = '^%s$'\n" "$(aerospace_regex_escape "$value")"
        fi
        run_layout=''
        run_workspace=''
        [ -n "$layout" ] && run_layout="'layout $layout'"
        case "$policy" in
            follow)
                [ -n "$run_layout" ] || run_workspace="'exec-and-forget /usr/bin/true'"
                ;;
            fixed|prefer)
                [ -n "$workspace" ] || continue
                run_workspace="'move-node-to-workspace $workspace'"
                ;;
            inherit)
                # A layout-only row: "shape this window, do not move it". The
                # shell functions have always honoured it, but this used to fall
                # into the `continue` below and emit no rule at all, so the same
                # record behaved one way at runtime and another in the generated
                # TOML. Nothing shipped reaches it today - a pack author writing
                # `id|X|-|floating` would have.
                [ -n "$run_layout" ] || continue
                ;;
            *) continue ;;
        esac
        if [ -n "$run_layout" ] && [ -n "$run_workspace" ]; then
            printf '    run = [%s, %s]\n\n' "$run_layout" "$run_workspace"
        elif [ -n "$run_layout" ]; then
            printf '    run = %s\n\n' "$run_layout"
        else
            printf '    run = %s\n\n' "$run_workspace"
        fi
    done < "$routes_file"
}

emit_user_on_window_detected_rules() {
    emit_routes_file_as_toml "$(aerospace_app_routes_file)" user
}

emit_captured_on_window_detected_rules() {
    [ -r "$(aerospace_captured_routes_file)" ] || return 0
    printf '%s\n' '# Locally captured desktop routes.'
    emit_routes_file_as_toml "$(aerospace_captured_routes_file)" captured
}

emit_advisor_on_window_detected_rules() {
    [ -r "$(aerospace_advisor_routes_file)" ] || return 0
    printf '%s\n' '# Local installation-advisor routes.'
    emit_routes_file_as_toml "$(aerospace_advisor_routes_file)" advisor
}

emit_pack_on_window_detected_rules() {
    local pack
    pack="$(aerospace_routing_pack)"
    [ "$pack" != 'none' ] || return 0
    printf '# Routing pack: %s\n' "$pack"
    emit_routes_file_as_toml "$(aerospace_routing_pack_file)" pack
}

emit_on_window_detected_rules_raw() {
    cat <<'TOML'
# Common secondary/dialog windows should stay with the workspace that opened them.
[[on-window-detected]]
    if.window-title-regex-substring = '^(Settings|Preferences|Options|Licenses|Choose|Select|Open|Save|Save As|Export|Import|Find|Replace|Print|Search|Keyboard Shortcuts|Extensions|Plugins|Account|Profile|Sign in|Login|设置|偏好设置|选项|关于|打开|保存|导出|导入|查找|替换|打印|账户|登录)( |$|:|-)'
    run = 'layout floating'

# JetBrains: keep main IDE windows tiled, but float obvious dialogs/tool windows.
[[on-window-detected]]
    if.app-name-regex-substring = '^(GoLand|IntelliJ IDEA|IntelliJ IDEA-EAP|WebStorm|PhpStorm|RustRover|PyCharm|CLion|DataGrip|Rider|Android Studio)$'
    if.window-title-regex-substring = '^(Welcome to|Settings|Preferences|Project Structure|Run/Debug Configurations|Edit Configuration|Plugins|Tip of the Day|New Project|Open File or Project|Attach Directory|About|Licenses|Choose|Select|Import|Export|Find|Replace|Search Everywhere|Local History|Commit|Push|Pull|Merge|Rebase|Checkout|Branch|Clone Repository|Refactor|Extract|Inline|Change Signature|Delete|Rename|Remove|Move|Copy|Add File to Git|Edit Commit Message|Confirm|Discard|Overwrite|File Already Exists|Resolve Conflicts)'
    run = 'layout floating'

# Float the macOS surfaces that behave like utility windows, then continue to
# placement rules. Named apps - chat clients, media players, the author's own
# tools - are rendered from the selected routing pack further down instead, so
# that a pack of `none` really does ship no app placement.
[[on-window-detected]]
    if.app-name-regex-substring = '^(Finder|访达|System Settings|System Preferences|系统设置|Activity Monitor|监视器|Stats|Mail|邮件|Photos|照片|Preview|预览|Microsoft PowerPoint|Keynote.*)$'
    check-further-callbacks = true
    run = 'layout floating'

# Primary work/browser/AI windows should stay tiled, even if the app restored a floating state.
[[on-window-detected]]
    if.app-id = 'com.blade.shadow-macos'
    check-further-callbacks = true
    run = 'layout tiling'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Warp|Kaku|Cursor|Visual Studio Code|Code|Code - Insiders|Sublime Text|GoLand|IntelliJ IDEA|IntelliJ IDEA-EAP|WebStorm|PhpStorm|RustRover|PyCharm|CLion|DataGrip|Rider|Android Studio|Arc|Dia|Safari|Microsoft Edge|Google Chrome|Firefox|Zen|Obsidian|MiaoYan|Cola|ChatGPT|ChatGPT Atlas|Gemini|Shadow|Shadow PC|ShadowPCDisplay)$'
    check-further-callbacks = true
    run = 'layout tiling'

TOML
}

if [ "${1:-}" = "--toml" ]; then
    emit_on_window_detected_rules
fi
