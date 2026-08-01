#!/usr/bin/env bash
# Shared assertion helpers for smoke tests.
#
# Every suite in tests/smoke/ used to carry its own copy of these functions, and
# the copies drifted: `assert_missing` means "this path does not exist" in
# advisor_smoke.sh and "this string is not in that string" in
# choice_architecture_smoke.sh. Two functions with one name and opposite
# argument meanings is how a test ends up asserting nothing at all.
#
# So the names here are unambiguous by construction: every helper says what it
# looks at (path / file / output) before it says what it wants. Existing suites
# are deliberately left alone - rewriting fourteen passing files to gain nothing
# but consistency is a bad trade - but new suites source this instead.
#
# Bash 3.2 only: no associative arrays, no ${var,,}, no mapfile.
#
# Counters are globals so a suite can print the standard footer:
#     smoke_summary "$(basename "$0")"

checks=0
failures=0

pass() {
  checks=$((checks + 1))
}

# fail <message> [detail]
fail() {
  local message="$1"
  local detail="${2:-}"

  checks=$((checks + 1))
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$message" >&2
  if [ -n "$detail" ]; then
    printf -- '--- detail ---\n%s\n--------------\n' "$detail" >&2
  fi
}

# assert_equal <expected> <actual> <label>
assert_equal() {
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "$3" "expected: [$1]
actual:   [$2]"
  fi
}

# assert_contains <haystack> <needle> <label>
assert_contains() {
  case "$1" in
    *"$2"*) pass ;;
    *) fail "$3" "missing substring: $2
in: $1" ;;
  esac
}

# assert_not_contains <haystack> <needle> <label>
assert_not_contains() {
  case "$1" in
    *"$2"*) fail "$3" "unexpected substring: $2
in: $1" ;;
    *) pass ;;
  esac
}

# assert_output_matches <output> <extended regex> <label>
# Prefer this over assert_contains for anything column-aligned: a needle like
# 'Workspace mode:     balanced' pins five spaces of formatting to the behavior
# under test, and breaks when a label is reworded.
assert_output_matches() {
  if printf '%s\n' "$1" | /usr/bin/grep -Eq -- "$2"; then
    pass
  else
    fail "$3" "no line matched: $2
in: $1"
  fi
}

# assert_output_lacks <output> <extended regex> <label>
assert_output_lacks() {
  if printf '%s\n' "$1" | /usr/bin/grep -Eq -- "$2"; then
    fail "$3" "unexpectedly matched: $2
in: $1"
  else
    pass
  fi
}

# assert_path_exists <path> <label>   (a symlink counts as existing)
assert_path_exists() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    pass
  else
    fail "$2" "missing path: $1"
  fi
}

# assert_path_absent <path> <label>
assert_path_absent() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    fail "$2" "unexpected path: $1"
  else
    pass
  fi
}

# assert_file_contains <file> <fixed string> <label>
assert_file_contains() {
  if /usr/bin/grep -Fq -- "$2" "$1" 2>/dev/null; then
    pass
  else
    fail "$3" "$(cat "$1" 2>/dev/null || printf '(unreadable: %s)' "$1")"
  fi
}

# assert_file_lacks <file> <fixed string> <label>
assert_file_lacks() {
  if /usr/bin/grep -Fq -- "$2" "$1" 2>/dev/null; then
    fail "$3" "$(cat "$1" 2>/dev/null || true)"
  else
    pass
  fi
}

# assert_status <expected> <actual> <label> [detail]
assert_status() {
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "$3" "expected exit $1, got $2
${4:-}"
  fi
}

# assert_nonzero <status> <label> [detail]
assert_nonzero() {
  if [ "$1" -ne 0 ]; then
    pass
  else
    fail "$2" "expected a non-zero exit, got 0
${3:-}"
  fi
}

# smoke_summary <suite name>
smoke_summary() {
  if [ "$failures" -gt 0 ]; then
    printf '\n%s: %s of %s checks failed\n' "$1" "$failures" "$checks" >&2
    exit 1
  fi
  printf '%s: ok (%s checks)\n' "$1" "$checks"
}
