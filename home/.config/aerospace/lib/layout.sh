#!/usr/bin/env bash
# Single source of truth for "which monitor plays which role" and "how many
# workspaces exist". Every script in this directory used to answer both
# questions by hard-coding one particular desk: three displays named by model,
# and thirteen workspaces. On any other Mac - which is every Mac but one -
# those names never appear, so startup scripts waited for displays that would
# never arrive and doctor.sh reported failures nobody could fix.
#
# The two answers now live in displays.conf and workspaces.conf next to this
# file, and everything else asks here.
#
# Roles, not names:
#   main   the display you work on
#   side   the secondary panel
#   stage  the recording / meeting / presentation screen
#
# A role is resolved against what is actually connected. Roles collapse onto
# each other when there is nothing left to resolve to (stage -> side -> main),
# so a single-display Mac is not a degraded mode: every role points at the one
# display and every workspace, shortcut and check keeps working.
#
# This file is a library. It defines functions and a few defaults and runs
# nothing on source, so it is safe under `set -euo pipefail` and safe to source
# more than once.

AEROSPACE_LAYOUT_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
AEROSPACE_CONFIG_DIR="${AEROSPACE_CONFIG_DIR:-$(dirname "$AEROSPACE_LAYOUT_LIB_DIR")}"

# Defaults used when a config file is missing or does not set a value. Empty
# monitor names are deliberate: an empty role resolves positionally from
# whatever is connected, which is correct on a machine nobody has told us
# about. displays.conf documents how to pin a role to a named display.
AEROSPACE_LAYOUT_DEFAULT_MAIN_WORKSPACES="1 2 3 4 5 6"
AEROSPACE_LAYOUT_DEFAULT_SIDE_WORKSPACES="7 8 9 10 11 12"
AEROSPACE_LAYOUT_DEFAULT_STAGE_WORKSPACES="13"

# Keys are handed to workspaces in this order by render-layout.sh. Thirteen
# entries is not a limit on workspaces, only on how many of them get a
# single-chord shortcut.
AEROSPACE_LAYOUT_WORKSPACE_KEYS="1 2 3 4 5 6 7 8 9 0 leftSquareBracket rightSquareBracket backslash"

aerospace_layout_roles() {
    printf 'main side stage\n'
}

# Collapses runs of whitespace so a config value can be written across lines or
# with stray spacing and still compare and iterate cleanly.
aerospace_layout_normalize_list() {
    local value="${1:-}"
    local item first=1

    for item in $value; do
        if [ "$first" -eq 1 ]; then
            printf '%s' "$item"
            first=0
        else
            printf ' %s' "$item"
        fi
    done
    printf '\n'
}

# Sources displays.conf and workspaces.conf. Values already present in the
# environment win over the files, so `AEROSPACE_MAIN_MONITOR_NAME=... script`
# keeps working for one-off runs and for tests.
aerospace_layout_load_config() {
    local env_main_monitor env_side_monitor env_stage_monitor
    local env_main_workspaces env_side_workspaces env_stage_workspaces
    local config_file profile_lib

    if [ "${AEROSPACE_LAYOUT_CONFIG_LOADED:-0}" = "1" ]; then
        return 0
    fi

    env_main_monitor="${AEROSPACE_MAIN_MONITOR_NAME:-}"
    env_side_monitor="${AEROSPACE_SIDE_MONITOR_NAME:-}"
    env_stage_monitor="${AEROSPACE_STAGE_MONITOR_NAME:-}"
    env_main_workspaces="${AEROSPACE_MAIN_WORKSPACES:-}"
    env_side_workspaces="${AEROSPACE_SIDE_WORKSPACES:-}"
    env_stage_workspaces="${AEROSPACE_STAGE_WORKSPACES:-}"

    AEROSPACE_MAIN_MONITOR_NAME=""
    AEROSPACE_SIDE_MONITOR_NAME=""
    AEROSPACE_STAGE_MONITOR_NAME=""
    AEROSPACE_MAIN_WORKSPACES="$AEROSPACE_LAYOUT_DEFAULT_MAIN_WORKSPACES"
    AEROSPACE_SIDE_WORKSPACES="$AEROSPACE_LAYOUT_DEFAULT_SIDE_WORKSPACES"
    AEROSPACE_STAGE_WORKSPACES="$AEROSPACE_LAYOUT_DEFAULT_STAGE_WORKSPACES"

    for config_file in displays workspaces; do
        if [ -r "$AEROSPACE_CONFIG_DIR/$config_file.conf" ]; then
            # shellcheck source=/dev/null
            . "$AEROSPACE_CONFIG_DIR/$config_file.conf"
        fi
    done

    # A named installer preset is a machine-owned layer above the shipped
    # AeroSpace defaults. It can collapse the author setup to six workspaces or
    # pin the author's three displays without editing the implementation files
    # that receive upstream fixes. Direct environment values still win below.
    profile_lib="${AI_FIRST_PROFILE_LIB:-$HOME/.config/ai-first/lib/profile.sh}"
    if [ -r "$profile_lib" ]; then
        # shellcheck source=/dev/null
        AI_FIRST_PROFILE_OVERRIDE_AEROSPACE=1
        . "$profile_lib"
        unset AI_FIRST_PROFILE_OVERRIDE_AEROSPACE
    fi

    [ -z "$env_main_monitor" ] || AEROSPACE_MAIN_MONITOR_NAME="$env_main_monitor"
    [ -z "$env_side_monitor" ] || AEROSPACE_SIDE_MONITOR_NAME="$env_side_monitor"
    [ -z "$env_stage_monitor" ] || AEROSPACE_STAGE_MONITOR_NAME="$env_stage_monitor"
    [ -z "$env_main_workspaces" ] || AEROSPACE_MAIN_WORKSPACES="$env_main_workspaces"
    [ -z "$env_side_workspaces" ] || AEROSPACE_SIDE_WORKSPACES="$env_side_workspaces"
    [ -z "$env_stage_workspaces" ] || AEROSPACE_STAGE_WORKSPACES="$env_stage_workspaces"

    AEROSPACE_MAIN_WORKSPACES="$(aerospace_layout_normalize_list "$AEROSPACE_MAIN_WORKSPACES")"
    AEROSPACE_SIDE_WORKSPACES="$(aerospace_layout_normalize_list "$AEROSPACE_SIDE_WORKSPACES")"
    AEROSPACE_STAGE_WORKSPACES="$(aerospace_layout_normalize_list "$AEROSPACE_STAGE_WORKSPACES")"

    AEROSPACE_LAYOUT_CONFIG_LOADED=1
}

aerospace_layout_monitor_name_for_role() {
    aerospace_layout_load_config

    case "${1:-}" in
        main) printf '%s\n' "$AEROSPACE_MAIN_MONITOR_NAME" ;;
        side) printf '%s\n' "$AEROSPACE_SIDE_MONITOR_NAME" ;;
        stage) printf '%s\n' "$AEROSPACE_STAGE_MONITOR_NAME" ;;
        *) printf '\n' ;;
    esac
}

aerospace_layout_workspaces_for_role() {
    aerospace_layout_load_config

    case "${1:-}" in
        main) printf '%s\n' "$AEROSPACE_MAIN_WORKSPACES" ;;
        side) printf '%s\n' "$AEROSPACE_SIDE_WORKSPACES" ;;
        stage) printf '%s\n' "$AEROSPACE_STAGE_WORKSPACES" ;;
        *) printf '\n' ;;
    esac
}

# Every configured workspace, in role order. This is the list AeroSpace,
# SketchyBar and the arrow-key navigation all iterate.
aerospace_layout_workspaces() {
    aerospace_layout_load_config
    aerospace_layout_normalize_list \
        "$AEROSPACE_MAIN_WORKSPACES $AEROSPACE_SIDE_WORKSPACES $AEROSPACE_STAGE_WORKSPACES"
}

aerospace_layout_workspace_count() {
    local workspace count=0

    for workspace in $(aerospace_layout_workspaces); do
        count=$((count + 1))
    done
    printf '%s\n' "$count"
}

aerospace_layout_role_for_workspace() {
    local needle="${1:-}"
    local role workspace

    for role in $(aerospace_layout_roles); do
        for workspace in $(aerospace_layout_workspaces_for_role "$role"); do
            if [ "$workspace" = "$needle" ]; then
                printf '%s\n' "$role"
                return 0
            fi
        done
    done

    return 1
}

# Maps a workspace an app rule asks for onto one that actually exists. App
# placement is written against the shipped thirteen workspaces; a user who cuts
# the set down to five should get their editor on workspace 5 rather than have
# AeroSpace conjure a fourteenth. With the shipped config every workspace maps
# to itself, so this is a no-op until someone edits workspaces.conf.
AEROSPACE_LAYOUT_CLAMPED="${AEROSPACE_LAYOUT_CLAMPED:-}"
aerospace_layout_clamp_workspace_var() {
    local needle="${1:-}"
    local workspace best="" last=""

    AEROSPACE_LAYOUT_CLAMPED="$needle"
    [ -n "$needle" ] || return 0

    for workspace in $(aerospace_layout_workspaces); do
        last="$workspace"
        if [ "$workspace" = "$needle" ]; then
            return 0
        fi
        case "$needle$workspace" in
            *[!0-9]*)
                continue
                ;;
        esac
        if [ "$workspace" -lt "$needle" ]; then
            best="$workspace"
        fi
    done

    if [ -n "$best" ]; then
        AEROSPACE_LAYOUT_CLAMPED="$best"
    elif [ -n "$last" ]; then
        AEROSPACE_LAYOUT_CLAMPED="$last"
    fi
}

aerospace_layout_clamp_workspace() {
    aerospace_layout_clamp_workspace_var "${1:-}"
    printf '%s\n' "$AEROSPACE_LAYOUT_CLAMPED"
}

# Rewrites `move-node-to-workspace N` targets on stdin through the clamp above.
# Pure shell so the generated TOML and the runtime placement in app-defaults.sh
# can never disagree about where an app belongs.
aerospace_layout_clamp_workspace_stream() {
    local line head tail workspace rest

    while IFS= read -r line; do
        case "$line" in
            *"move-node-to-workspace "[0-9]*)
                head="${line%%move-node-to-workspace *}"
                tail="${line#*move-node-to-workspace }"
                workspace="${tail%%[!0-9]*}"
                rest="${tail#"$workspace"}"
                aerospace_layout_clamp_workspace_var "$workspace"
                printf '%smove-node-to-workspace %s%s\n' "$head" "$AEROSPACE_LAYOUT_CLAMPED" "$rest"
                ;;
            *)
                printf '%s\n' "$line"
                ;;
        esac
    done
}

# Homebrew's path on Apple silicon is the last resort, not the first guess:
# an Intel Mac installs to /usr/local/bin, and AeroSpace's exec-and-forget does
# not always hand scripts a PATH that has either.
aerospace_layout_bin() {
    local found

    if [ -n "${AEROSPACE_BIN:-}" ]; then
        printf '%s\n' "$AEROSPACE_BIN"
        return 0
    fi
    if [ -n "${AEROSPACE:-}" ]; then
        printf '%s\n' "$AEROSPACE"
        return 0
    fi

    found="$(command -v aerospace 2>/dev/null || true)"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi

    printf '%s\n' '/opt/homebrew/bin/aerospace'
}

# "<monitor-id>\t<monitor-name>" per connected monitor, empty when AeroSpace is
# not answering yet. Never fails: a caller that cannot see monitors has to keep
# working, not abort.
#
# Guarded assignment throughout: app-defaults.sh sources this file too, so a
# script that resolves monitors and then sources it must not have its answers
# reset out from under it.
AEROSPACE_LAYOUT_MONITOR_LINES="${AEROSPACE_LAYOUT_MONITOR_LINES:-}"
AEROSPACE_LAYOUT_MONITORS_READ="${AEROSPACE_LAYOUT_MONITORS_READ:-0}"
aerospace_layout_refresh_monitors() {
    local bin

    bin="$(aerospace_layout_bin)"
    AEROSPACE_LAYOUT_MONITOR_LINES="$("$bin" list-monitors --format "%{monitor-id}$(printf '\t')%{monitor-name}" 2>/dev/null || true)"
    AEROSPACE_LAYOUT_MONITORS_READ=1
}

aerospace_layout_monitor_lines() {
    if [ "$AEROSPACE_LAYOUT_MONITORS_READ" -eq 0 ]; then
        aerospace_layout_refresh_monitors
    fi
    printf '%s' "$AEROSPACE_LAYOUT_MONITOR_LINES"
    [ -z "$AEROSPACE_LAYOUT_MONITOR_LINES" ] || printf '\n'
}

aerospace_layout_monitor_count() {
    local lines count=0 line

    lines="$(aerospace_layout_monitor_lines)"
    [ -n "$lines" ] || {
        printf '0\n'
        return 0
    }

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        count=$((count + 1))
    done <<EOF
$lines
EOF

    printf '%s\n' "$count"
}

# Resolution result. Names are what AeroSpace calls the display; ids are what
# `aerospace list-monitors` numbered it. Both are empty only when AeroSpace
# reported no monitors at all.
AEROSPACE_RESOLVED_MAIN_NAME="${AEROSPACE_RESOLVED_MAIN_NAME:-}"
AEROSPACE_RESOLVED_SIDE_NAME="${AEROSPACE_RESOLVED_SIDE_NAME:-}"
AEROSPACE_RESOLVED_STAGE_NAME="${AEROSPACE_RESOLVED_STAGE_NAME:-}"
AEROSPACE_RESOLVED_MAIN_ID="${AEROSPACE_RESOLVED_MAIN_ID:-}"
AEROSPACE_RESOLVED_SIDE_ID="${AEROSPACE_RESOLVED_SIDE_ID:-}"
AEROSPACE_RESOLVED_STAGE_ID="${AEROSPACE_RESOLVED_STAGE_ID:-}"
AEROSPACE_MONITOR_COUNT="${AEROSPACE_MONITOR_COUNT:-0}"

# Three passes, in this order:
#   1. a role whose configured name is connected takes that monitor
#   2. a role with no name left takes the next monitor nobody claimed
#   3. whatever is still unresolved collapses: stage -> side -> main -> first
#
# Pass 2 is what makes an unedited config correct on a stranger's desk; pass 3
# is what makes one display carry all three roles instead of two of them
# pointing at nothing.
aerospace_layout_resolve() {
    local lines line name index count
    local role configured
    local -a monitor_ids monitor_names monitor_claimed

    aerospace_layout_load_config

    monitor_ids=()
    monitor_names=()
    monitor_claimed=()

    AEROSPACE_RESOLVED_MAIN_NAME=""
    AEROSPACE_RESOLVED_SIDE_NAME=""
    AEROSPACE_RESOLVED_STAGE_NAME=""
    AEROSPACE_RESOLVED_MAIN_ID=""
    AEROSPACE_RESOLVED_SIDE_ID=""
    AEROSPACE_RESOLVED_STAGE_ID=""
    AEROSPACE_MONITOR_COUNT=0

    lines="$(aerospace_layout_monitor_lines)"
    if [ -n "$lines" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            name="${line#*	}"
            monitor_ids[${#monitor_ids[@]}]="${line%%	*}"
            monitor_names[${#monitor_names[@]}]="${name%%	*}"
            monitor_claimed[${#monitor_claimed[@]}]=0
        done <<EOF
$lines
EOF
    fi

    count=${#monitor_ids[@]}
    AEROSPACE_MONITOR_COUNT="$count"

    if [ "$count" -eq 0 ]; then
        # Nothing to resolve against: report the configured names so callers can
        # still print something meaningful, with no ids.
        AEROSPACE_RESOLVED_MAIN_NAME="$AEROSPACE_MAIN_MONITOR_NAME"
        AEROSPACE_RESOLVED_SIDE_NAME="$AEROSPACE_SIDE_MONITOR_NAME"
        AEROSPACE_RESOLVED_STAGE_NAME="$AEROSPACE_STAGE_MONITOR_NAME"
        return 0
    fi

    for role in $(aerospace_layout_roles); do
        configured="$(aerospace_layout_monitor_name_for_role "$role")"
        [ -n "$configured" ] || continue

        index=0
        while [ "$index" -lt "$count" ]; do
            if [ "${monitor_claimed[$index]}" -eq 0 ] && [ "${monitor_names[$index]}" = "$configured" ]; then
                monitor_claimed[$index]=1
                aerospace_layout_set_resolved "$role" "${monitor_names[$index]}" "${monitor_ids[$index]}"
                break
            fi
            index=$((index + 1))
        done
    done

    for role in $(aerospace_layout_roles); do
        [ -z "$(aerospace_layout_resolved_name "$role")" ] || continue

        index=0
        while [ "$index" -lt "$count" ]; do
            if [ "${monitor_claimed[$index]}" -eq 0 ]; then
                monitor_claimed[$index]=1
                aerospace_layout_set_resolved "$role" "${monitor_names[$index]}" "${monitor_ids[$index]}"
                break
            fi
            index=$((index + 1))
        done
    done

    if [ -z "$AEROSPACE_RESOLVED_MAIN_NAME" ]; then
        AEROSPACE_RESOLVED_MAIN_NAME="${monitor_names[0]}"
        AEROSPACE_RESOLVED_MAIN_ID="${monitor_ids[0]}"
    fi
    if [ -z "$AEROSPACE_RESOLVED_SIDE_NAME" ]; then
        AEROSPACE_RESOLVED_SIDE_NAME="$AEROSPACE_RESOLVED_MAIN_NAME"
        AEROSPACE_RESOLVED_SIDE_ID="$AEROSPACE_RESOLVED_MAIN_ID"
    fi
    if [ -z "$AEROSPACE_RESOLVED_STAGE_NAME" ]; then
        AEROSPACE_RESOLVED_STAGE_NAME="$AEROSPACE_RESOLVED_SIDE_NAME"
        AEROSPACE_RESOLVED_STAGE_ID="$AEROSPACE_RESOLVED_SIDE_ID"
    fi
}

aerospace_layout_set_resolved() {
    case "${1:-}" in
        main)
            AEROSPACE_RESOLVED_MAIN_NAME="${2:-}"
            AEROSPACE_RESOLVED_MAIN_ID="${3:-}"
            ;;
        side)
            AEROSPACE_RESOLVED_SIDE_NAME="${2:-}"
            AEROSPACE_RESOLVED_SIDE_ID="${3:-}"
            ;;
        stage)
            AEROSPACE_RESOLVED_STAGE_NAME="${2:-}"
            AEROSPACE_RESOLVED_STAGE_ID="${3:-}"
            ;;
    esac
}

aerospace_layout_resolved_name() {
    case "${1:-}" in
        main) printf '%s\n' "$AEROSPACE_RESOLVED_MAIN_NAME" ;;
        side) printf '%s\n' "$AEROSPACE_RESOLVED_SIDE_NAME" ;;
        stage) printf '%s\n' "$AEROSPACE_RESOLVED_STAGE_NAME" ;;
        *) printf '\n' ;;
    esac
}

aerospace_layout_resolved_id() {
    case "${1:-}" in
        main) printf '%s\n' "$AEROSPACE_RESOLVED_MAIN_ID" ;;
        side) printf '%s\n' "$AEROSPACE_RESOLVED_SIDE_ID" ;;
        stage) printf '%s\n' "$AEROSPACE_RESOLVED_STAGE_ID" ;;
        *) printf '\n' ;;
    esac
}

# Distinct resolved monitor names, one per line. One display collapses to one
# name, which is exactly what the per-monitor gap rules need.
aerospace_layout_resolved_monitor_names() {
    local role name seen=""

    for role in $(aerospace_layout_roles); do
        name="$(aerospace_layout_resolved_name "$role")"
        [ -n "$name" ] || continue
        case "$seen" in
            *"|$name|"*)
                continue
                ;;
        esac
        seen="$seen|$name|"
        printf '%s\n' "$name"
    done
}

# Waits for the display list to settle at login, then returns. It deliberately
# does not wait for any particular monitor: the old version blocked for ten
# seconds on every boot of every Mac that did not have the author's two
# external displays, which is every Mac but one. Settled means "AeroSpace
# answered, and the number of monitors stopped changing" - or, as a fast path,
# "every monitor named in displays.conf is already here".
#
# Returns 1 only when AeroSpace never reported a single monitor.
aerospace_layout_wait_for_monitors() {
    local attempts="${1:-${AEROSPACE_MONITOR_WAIT_ATTEMPTS:-32}}"
    local interval="${AEROSPACE_MONITOR_WAIT_INTERVAL:-0.25}"
    local stable_needed="${AEROSPACE_MONITOR_WAIT_STABLE:-3}"
    local pending_stable="${AEROSPACE_MONITOR_WAIT_STABLE_PENDING:-12}"
    local attempt=0 stable=0 count last_count=-1
    local role configured names missing

    aerospace_layout_load_config

    # A config that names displays is a promise that those displays exist, so
    # give them time to wake up: external monitors are routinely several
    # seconds behind the login that started this. A config that names none
    # cannot be waiting for anything in particular, so it settles as soon as
    # the display list stops moving - half a second, not twenty.
    for role in $(aerospace_layout_roles); do
        if [ -n "$(aerospace_layout_monitor_name_for_role "$role")" ]; then
            stable_needed="$pending_stable"
            break
        fi
    done

    while [ "$attempt" -lt "$attempts" ]; do
        aerospace_layout_refresh_monitors
        count="$(aerospace_layout_monitor_count)"

        if [ "$count" -gt 0 ]; then
            missing=0
            names="$(printf '%s\n' "$AEROSPACE_LAYOUT_MONITOR_LINES" | /usr/bin/cut -f2-)"
            for role in $(aerospace_layout_roles); do
                configured="$(aerospace_layout_monitor_name_for_role "$role")"
                [ -n "$configured" ] || continue
                if ! printf '%s\n' "$names" | /usr/bin/grep -Fxq "$configured"; then
                    missing=1
                fi
            done

            if [ "$missing" -eq 0 ]; then
                return 0
            fi

            if [ "$count" -eq "$last_count" ]; then
                stable=$((stable + 1))
            else
                stable=1
            fi
            last_count="$count"

            if [ "$stable" -ge "$stable_needed" ]; then
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        sleep "$interval"
    done

    [ "$(aerospace_layout_monitor_count)" -gt 0 ]
}
