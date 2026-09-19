#!/usr/bin/env bash
# Shared by copy deploy and renderers. These are accidental-write protections,
# not an OS security boundary against another process changing a path mid-write.

ai_first_write_path_check() {
    local target="$1" allow_leaf_link="${2:-0}" current
    case "$target" in
        /*) ;;
        *) printf 'Refusing non-absolute write target: %s\n' "$target" >&2; return 1 ;;
    esac
    case "$target/" in
        *'/../'*|*'/./'*|*'//'*)
            printf 'Refusing non-normalized write target: %s\n' "$target" >&2; return 1 ;;
    esac
    current="$target"
    while [ "$current" != / ] && [ "$current" != "$HOME" ]; do
        if [ -L "$current" ]; then
            if [ "$current" = "$target" ] && [ "$allow_leaf_link" = 1 ]; then
                : # The caller must back up and replace the link, never follow it.
            elif { [ "$current" = /tmp ] && [ "$(readlink "$current")" = private/tmp ]; } ||
                 { [ "$current" = /var ] && [ "$(readlink "$current")" = private/var ]; }; then
                : # macOS aliases, outside the managed HOME boundary.
            else
                printf 'Refusing write through symlink: %s (target %s)\n' "$current" "$target" >&2
                return 1
            fi
        fi
        current="${current%/*}"
        [ -n "$current" ] || current=/
    done
}

# An inherited token makes installer -> renderer calls one cooperating writer.
# A crash leaves the lock for explicit inspection; never guess that it is stale.
ai_first_write_lock_acquire() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/ai-first-dotfiles" owner
    ai_first_write_path_check "$state/write.lock" || return 1
    mkdir -p "$state" || return 1
    if [ -n "${AI_FIRST_WRITE_LOCK_TOKEN:-}" ] &&
       [ "${AI_FIRST_WRITE_LOCK_DIR:-}" = "$state/write.lock" ] &&
       [ -r "$state/write.lock/owner" ]; then
        owner="$(cat "$state/write.lock/owner")"
        if [ "$owner" = "$AI_FIRST_WRITE_LOCK_TOKEN" ] && kill -0 "${owner%%:*}" 2>/dev/null; then
            return 0
        fi
    fi
    if ! mkdir -m 700 "$state/write.lock" 2>/dev/null; then
        printf 'Another write or an interrupted write owns %s; inspect it before retrying.\n' "$state/write.lock" >&2
        return 75
    fi
    AI_FIRST_WRITE_LOCK_DIR="$state/write.lock"
    AI_FIRST_WRITE_LOCK_TOKEN="$$:$RANDOM:$RANDOM"
    if ! printf '%s\n' "$AI_FIRST_WRITE_LOCK_TOKEN" >"$AI_FIRST_WRITE_LOCK_DIR/owner"; then
        rmdir "$AI_FIRST_WRITE_LOCK_DIR" 2>/dev/null || true
        return 1
    fi
    AI_FIRST_WRITE_LOCK_OWNED="$AI_FIRST_WRITE_LOCK_TOKEN"
    export AI_FIRST_WRITE_LOCK_DIR AI_FIRST_WRITE_LOCK_TOKEN
}

ai_first_write_lock_release() {
    if [ -n "${AI_FIRST_WRITE_LOCK_OWNED:-}" ] &&
       [ -f "${AI_FIRST_WRITE_LOCK_DIR:-}/owner" ] &&
       [ "$(cat "$AI_FIRST_WRITE_LOCK_DIR/owner")" = "$AI_FIRST_WRITE_LOCK_OWNED" ]; then
        rm -f "$AI_FIRST_WRITE_LOCK_DIR/owner"
        rmdir "$AI_FIRST_WRITE_LOCK_DIR" 2>/dev/null || true
        unset AI_FIRST_WRITE_LOCK_OWNED AI_FIRST_WRITE_LOCK_TOKEN AI_FIRST_WRITE_LOCK_DIR
    fi
}

# Capture identity and content, so a user edit during staging becomes a conflict.
# This narrows the race window; it is not an atomic compare-and-swap primitive.
ai_first_file_state() {
    local target="$1" identity
    if [ -L "$target" ]; then
        printf 'link:%s\n' "$(readlink "$target")"
    elif [ -f "$target" ]; then
        identity="$(stat -f '%i:%z:%m:%c:%p' "$target")" || return 1
        printf 'file:%s:' "$identity"
        cksum <"$target"
    elif [ -e "$target" ]; then
        stat -f 'other:%i:%z:%m:%c:%p' "$target"
    else
        printf 'absent\n'
    fi
}

# The caller owns the lock. A sibling temp makes replacement atomic; a unique
# adjacent backup prevents following or overwriting a predictable backup link.
ai_first_replace_file() {
    local source="$1" target="$2" label="$3" expected="${4:-}" staged backup mode current
    ai_first_write_path_check "$target" || return 1
    [ -n "$expected" ] || expected="$(ai_first_file_state "$target")" || return 1
    staged="$(mktemp "${target}.new.XXXXXX")" || return 1
    if ! cp "$source" "$staged"; then rm -f "$staged"; return 1; fi
    mode="$(stat -f '%OLp' "$target" 2>/dev/null || true)"
    if [ -n "$mode" ]; then chmod "$mode" "$staged" || { rm -f "$staged"; return 1; }; fi
    current="$(ai_first_file_state "$target")" || { rm -f "$staged"; return 1; }
    if [ "$current" != "$expected" ]; then
        rm -f "$staged"
        printf 'Conflict: %s changed during rendering; not replaced.\n' "$target" >&2
        return 1
    fi
    backup="$(mktemp "${target}.bak-$(date +%Y%m%d-%H%M%S)-${label}.XXXXXX")" || { rm -f "$staged"; return 1; }
    if ! cp -p "$target" "$backup" || ! ai_first_write_path_check "$target" || ! mv "$staged" "$target"; then
        rm -f "$staged"
        printf 'Replacement failed; inspect original and backup: %s %s\n' "$target" "$backup" >&2
        return 1
    fi
    printf 'Rendered %s (previous file kept at %s); not activated.\n' "$target" "$backup"
}
